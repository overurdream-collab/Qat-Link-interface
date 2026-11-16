import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';
const url=process.env.FIN08_TEST_DATABASE_URL;

test('FIN-15 PostgreSQL: amount proposal never alters original or posts money; merchant creates new claim needing customer consent',
  {skip:!url},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin15-audited-adjustment-test-strong-secret-123'});
    const s=randomUUID().slice(0,8);
    const merchant={id:'fin15-M-'+s,role:'merchant'};
    const foreign={id:'fin15-F-'+s,role:'merchant'};
    const customer={id:'fin15-C-'+s,role:'customer'};
    const stranger={id:'fin15-X-'+s,role:'customer'};
    const identity={id:'fin15-trusted-id',role:'identity_service'};
    const phone='+96775'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const key=x=>'fin15-'+s+'-'+x;
    const create=async(type,amount,name)=>{
      const result=await store.createClaim(merchant,{
        contact_id:contact.id,type,amount,currency:'YER',description:'Original purchase'
      },key(name));
      return result.claim.id;
    };
    let contact;
    try{
      await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Seller'});
      await store.onboardMerchant(identity,{merchant_id:foreign.id,verified_display_name:'Other seller'});
      contact=await store.createContact(merchant,{name:'Review customer',phone});
      const old=await create('debt','20000','debt');
      const historicDate=(await pool.query('SELECT occurred_at FROM merchant_claims WHERE id=$1',[old])).rows[0].occurred_at;
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('phone-proof')});
      const initialRelation=(await store.listCustomerRelationships(customer,{})).items[0];
      const first=await store.adjustments.request(customer,old,{
        proposed_amount:'15000',reason:'The invoice total was lower'});
      assert.equal(first.status,'pending');
      const replay=await store.adjustments.request(customer,old,{
        proposed_amount:'15000.0000',reason:'The invoice total was lower'});
      assert.equal(replay.replayed,true);
      assert.equal(replay.adjustment_id,first.adjustment_id);
      await assert.rejects(()=>store.adjustments.request(customer,old,{
        proposed_amount:'30000',reason:'Different request'}),{status:409});
      await assert.rejects(()=>store.decideClaim(customer,old,{decision:'accept'}),{status:409});
      await assert.rejects(()=>store.batch.decideHistoricalClaims(customer,{
        decisions:[{id:old,decision:'accept'}]}),{status:409});
      await assert.rejects(()=>store.adjustments.decide(foreign,first.adjustment_id,{
        decision:'accept'}),{status:404});
      assert.equal((await store.summary(merchant)).currencies.find(x=>x.currency==='YER')
        .awaiting_customer_or_relationship,'20000.0000');
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE merchant_id=$1',
        [merchant.id])).rows[0].n,0);
      await store.adjustments.decide(merchant,first.adjustment_id,{decision:'reject'});
      assert.equal((await store.claimsInbox(customer,{})).items.find(x=>x.claim_id===old).stage,'awaiting_review');

      const second=await store.adjustments.request(customer,old,{
        proposed_amount:'25000',reason:'Additional quantity agreed'});
      const accepted=await store.adjustments.decide(merchant,second.adjustment_id,{decision:'accept'});
      assert.equal(accepted.status,'accepted');
      assert.ok(accepted.replacement_claim_id);
      assert.notEqual(accepted.replacement_claim_id,old);
      const replacement=accepted.replacement_claim_id;
      assert.equal((await store.adjustments.decide(merchant,second.adjustment_id,{
        decision:'accept'})).replacement_claim_id,replacement);
      await assert.rejects(()=>store.adjustments.decide(merchant,second.adjustment_id,{
        decision:'reject'}),{status:409});

      const all=await pool.query(
        'SELECT id,amount::text,occurred_at,source_claim_id,superseded_by_claim_id '+
        'FROM merchant_claims WHERE id=ANY($1::uuid[]) ORDER BY id',
        [[old,replacement]]);
      const savedOld=all.rows.find(x=>x.id===old);
      const savedNew=all.rows.find(x=>x.id===replacement);
      assert.equal(savedOld.amount,'20000.0000');
      assert.equal(savedOld.superseded_by_claim_id,replacement);
      assert.equal(savedNew.amount,'25000.0000');
      assert.equal(savedNew.source_claim_id,old);
      assert.equal(savedNew.occurred_at.toISOString(),historicDate.toISOString());
      const inbox=await store.claimsInbox(customer,{});
      assert.equal(inbox.items.find(x=>x.claim_id===old).stage,'superseded');
      assert.equal(inbox.items.find(x=>x.claim_id===replacement).stage,'awaiting_review');
      assert.equal((await store.summary(merchant)).currencies.find(x=>x.currency==='YER')
        .awaiting_customer_or_relationship,'25000.0000');
      await assert.rejects(()=>store.decideClaim(customer,old,{decision:'accept'}),{status:409});
      assert.equal((await store.decideClaim(customer,replacement,{decision:'accept'})).ledger_posted,false);
      const relation=await store.decideRelationship(customer,initialRelation.relationship_id,{decision:'accept'});
      assert.equal(relation.newly_posted_debts,1);
      assert.equal((await store.ledger.balances(customer,initialRelation.relationship_id)).currencies.find(
        x=>x.currency==='YER').balance,'25000.0000');
      const posted=await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE source_claim_id=$1',
        [replacement]);
      assert.equal(posted.rows[0].n,1);

      // The same correction flow also protects historical customer payments.
      const payment=await create('payment','5000','payment');
      const payProposal=await store.adjustments.request(customer,payment,{
        proposed_amount:'3000',reason:'Actual payment receipt was 3000'});
      const payAccepted=await store.adjustments.decide(merchant,payProposal.adjustment_id,{
        decision:'accept'});
      await store.decideClaim(customer,payAccepted.replacement_claim_id,{decision:'accept'});
      assert.equal((await store.ledger.balances(customer,initialRelation.relationship_id)).currencies.find(
        x=>x.currency==='YER').balance,'22000.0000');
      assert.equal((await pool.query('SELECT amount::text FROM merchant_claims WHERE id=$1',[payment]))
        .rows[0].amount,'5000.0000');

      await store.revokeProof(identity,{proof_reference:key('phone-proof')});
      await assert.rejects(()=>store.adjustments.request(customer,old,{
        proposed_amount:'30000',reason:'Must not work after proof revoked'}),{status:404});
      await assert.rejects(()=>store.decideClaim(stranger,replacement,{decision:'accept'}),{status:404});
    }finally{await pool.end();}
  });
