import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const url=process.env.FIN08_TEST_DATABASE_URL;

test('FIN-10: joining receives every merchant link request pending, independently of debts',
  {skip:!url}, async()=>{
    const { Pool }=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin10-test-secret-for-hmac-signatures-longer-than-32'});
    const suffix=randomUUID().slice(0,8);
    const identity={id:'identity-test',role:'identity_service'};
    const customer={id:'joined-'+suffix,role:'customer'};
    const other={id:'other-'+suffix,role:'customer'};
    const m1={id:'merchant-one-'+suffix,role:'merchant'};
    const m2={id:'merchant-two-'+suffix,role:'merchant'};
    const phone='+96778'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    try {
      await store.onboardMerchant(identity,{merchant_id:m1.id,verified_display_name:'Merchant One'});
      await store.onboardMerchant(identity,{merchant_id:m2.id,verified_display_name:'Merchant Two'});
      const contactOne=await store.createContact(m1,{name:'One Private Contact',phone});
      const contactTwo=await store.createContact(m2,{name:'Two Private Contact',phone});
      const claim=await store.createClaim(m1,{contact_id:contactOne.id,amount:'125.50',currency:'YER'},'fin10-claim-'+suffix);
      // Prior to verified ownership: no relation can be accepted and no debt is posted.
      assert.equal((await store.customerRelationships(customer,{})).items.length,0);
      assert.equal((await store.claimsInbox(customer,{})).items.length,0);
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:'proof-fin10-'+suffix});
      const first=await store.customerRelationships(customer,{limit:1});
      assert.equal(first.items.length,1);
      assert.ok(first.next_cursor);
      const second=await store.customerRelationships(customer,{limit:1,cursor:first.next_cursor});
      const all=[...first.items,...second.items];
      assert.equal(second.next_cursor,null);
      assert.equal(all.length,2);
      assert.deepEqual(new Set(all.map(x=>x.merchant_id)),new Set([m1.id,m2.id]));
      assert.ok(all.every(x=>x.status==='pending'));
      assert.deepEqual(new Set(all.map(x=>x.merchant_display_name)),
        new Set(['Merchant One','Merchant Two']));
      assert.equal((await store.customerRelationships(other,{})).items.length,0);
      await assert.rejects(
        ()=>store.customerRelationships(other,{limit:1,cursor:first.next_cursor}),{status:422});
      const merchantPrior=await store.requestRelationship(m1,{contact_id:contactOne.id});
      assert.equal(merchantPrior.already_exists,true);
      const relOne=all.find(x=>x.merchant_id===m1.id);
      assert.equal(merchantPrior.relationship_id,relOne.relationship_id);
      // Accepting the merchant link alone cannot auto-approve any prior claim.
      const confirmed=await store.decideRelationship(customer,relOne.relationship_id,{decision:'accept'});
      assert.equal(confirmed.status,'approved');
      assert.equal(confirmed.newly_posted_debts,0);
      assert.equal((await store.claimsInbox(customer,{})).items.find(x=>x.claim_id===claim.claim.id).stage,'awaiting_review');
      const count=()=>pool.query(
        'SELECT count(*)::int AS n FROM financial_movements WHERE source_claim_id=$1',[claim.claim.id]
      ).then(r=>r.rows[0].n);
      assert.equal(await count(),0);
      await store.decideClaim(customer,claim.claim.id,{decision:'accept'});
      await store.decideClaim(customer,claim.claim.id,{decision:'accept'});
      assert.equal(await count(),1);
      // The second merchant can be rejected without touching the first merchant's claims.
      const relTwo=all.find(x=>x.merchant_id===m2.id);
      await store.decideRelationship(customer,relTwo.relationship_id,{decision:'reject'});
      const after=await store.customerRelationships(customer,{limit:10});
      assert.equal(after.items.find(x=>x.merchant_id===m1.id).status,'approved');
      assert.equal(after.items.find(x=>x.merchant_id===m2.id).status,'rejected');
      const repeat=await store.requestRelationship(m2,{contact_id:contactTwo.id});
      assert.equal(repeat.status,'rejected');
      assert.equal(repeat.already_exists,true);
      // Repeated verification is not an invitation to duplicate a relationship.
      await store.verifyPhone(identity,{customer_id:customer.id,phone,
        proof_reference:'proof-fin10-extra-'+suffix});
      assert.equal((await store.customerRelationships(customer,{})).items.length,2);
      // Another verified owner on the same number must fail closed, including old links.
      await store.verifyPhone(identity,{customer_id:other.id,phone,
        proof_reference:'proof-fin10-conflict-'+suffix});
      assert.equal((await store.customerRelationships(customer,{})).items.length,0);
      assert.equal((await store.customerRelationships(other,{})).items.length,0);
      assert.equal(await count(),1);
    } finally {await pool.end();}
  });
