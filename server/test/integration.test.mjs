import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

// Runs only when an ephemeral PostgreSQL test database is explicitly provided.
// CI supplies one and applies sql/001_fin08.sql beforehand.
const url=process.env.FIN08_TEST_DATABASE_URL;
test('FIN-08 PostgreSQL E2E: historic claims, independent consent, durable ledger, isolation and fail closed',
  {skip:!url}, async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'test-only-do-not-use-in-production-'+'x'.repeat(20)});
    const suffix=randomUUID().slice(0,8);
    const m1={id:`merchant-${suffix}-A`,role:'merchant'};
    const m2={id:`merchant-${suffix}-B`,role:'merchant'};
    const customer={id:`customer-${suffix}`,role:'customer'};
    const impostor={id:`impostor-${suffix}`,role:'customer'};
    const identity={id:'identity-service',role:'identity_service'};
    const phone='+96777'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    try{
      await store.onboardMerchant(identity,{merchant_id:m1.id,verified_display_name:'Merchant One'});
      await store.onboardMerchant(identity,{merchant_id:m2.id,verified_display_name:'Merchant Two'});
      const c1=await store.createContact(m1,{name:'Pending Customer',phone});
      const c2=await store.createContact(m2,{name:'Same Customer',phone});
      const create=(m,contactId,key,amount,unit)=>store.createClaim(m,{contact_id:contactId,amount,currency:unit},key);
      const a=await create(m1,c1.id,`claim-${suffix}-a`,'1250.00','YER');
      const b=await create(m1,c1.id,`claim-${suffix}-b`,'5.25','USD');
      const c=await create(m2,c2.id,`claim-${suffix}-c`,'200.00','SAR');
      assert.equal((await create(m1,c1.id,`claim-${suffix}-a`,'1250.00','YER')).claim.id,a.claim.id);
      await assert.rejects(()=>create(m1,c1.id,`claim-${suffix}-a`,'999','YER'),{status:409});
      await assert.rejects(()=>create(m2,c1.id,`claim-${suffix}-cross`,'1','YER'),{status:404});
      let summary=await store.summary(m1);
      assert.equal(summary.currencies.find(r=>r.currency==='YER').outside_app,'1250.0000');
      assert.equal((await store.claimsInbox(customer,{})).items.length,0);
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:`proof-${suffix}`});
      const inbox=await store.claimsInbox(customer,{limit:2});
      assert.equal(inbox.items.length,2);
      assert.ok(inbox.next_cursor);
      const older=await store.claimsInbox(customer,{limit:2,cursor:inbox.next_cursor});
      assert.equal(older.items.length,1);
      assert.deepEqual(new Set([...inbox.items,...older.items].map(x=>x.claim_id)),new Set([a.claim.id,b.claim.id,c.claim.id]));
      assert.equal((await store.claimsInbox(impostor,{})).items.length,0);
      const accept=await store.decideClaim(customer,a.claim.id,{decision:'accept'});
      assert.equal(accept.ledger_posted,false);
      assert.equal(await countMovements(pool,a.claim.id),0);
      await store.decideClaim(customer,b.claim.id,{decision:'reject'});
      await assert.rejects(()=>store.decideClaim(customer,b.claim.id,{decision:'accept'}),{status:409});
      const request=await store.requestRelationship(m1,{contact_id:c1.id});
      assert.equal((await store.summary(m1)).currencies.find(r=>r.currency==='YER').awaiting_customer_or_relationship,'1250.0000');
      assert.equal(await countMovements(pool,a.claim.id),0);
      const relationship=await store.decideRelationship(customer,request.relationship_id,{decision:'accept'});
      assert.equal(relationship.newly_posted_debts,1);
      assert.equal(await countMovements(pool,a.claim.id),1);
      assert.equal(await countMovements(pool,b.claim.id),0);
      await store.decideRelationship(customer,request.relationship_id,{decision:'accept'});
      await store.decideClaim(customer,a.claim.id,{decision:'accept'});
      assert.equal(await countMovements(pool,a.claim.id),1);
      summary=await store.summary(m1);
      assert.equal(summary.currencies.find(r=>r.currency==='YER').approved_from_claims,'1250.0000');
      assert.match(summary.currencies.find(r=>r.currency==='YER').outside_app,/^0(?:\.0+)?$/);
      assert.match((await store.summary(m2)).currencies.find(r=>r.currency==='SAR').approved_from_claims,/^0(?:\.0+)?$/);
      // A second distinct verified account now claims the SAME phone: no
      // customer gets the old private inbox until identity conflict resolved.
      await store.verifyPhone(identity,{customer_id:impostor.id,phone,proof_reference:`proof-impostor-${suffix}`});
      assert.equal((await store.claimsInbox(customer,{})).items.length,0);
      assert.equal((await store.claimsInbox(impostor,{})).items.length,0);
      await assert.rejects(()=>store.decideClaim(impostor,c.claim.id,{decision:'accept'}),{status:404});
    }finally{await pool.end();}
  });
async function countMovements(pool,sourceClaimId){
 const q=await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE source_claim_id=$1',[sourceClaimId]);
 return q.rows[0].n;
}