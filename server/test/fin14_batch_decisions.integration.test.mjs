import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const url=process.env.FIN08_TEST_DATABASE_URL;

test('FIN-14: explicit selected debt/payment batch is atomic, isolated and never approves relationships',
  {skip:!url},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin14-atomic-customer-batch-integration-secret'});
    const s=randomUUID().slice(0,8);
    const merchantA={id:'fin14-A-'+s,role:'merchant'};
    const merchantB={id:'fin14-B-'+s,role:'merchant'};
    const customer={id:'fin14-c-'+s,role:'customer'};
    const foreign={id:'fin14-foreign-'+s,role:'customer'};
    const identity={id:'fin14-trusted-id',role:'identity_service'};
    const phoneA='+96771'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const phoneB='+96773'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const claim=async(merchant,contact,amount,currency,type,tag)=>
      (await store.createClaim(merchant,{contact_id:contact.id,amount,currency,type},
        'fin14-'+s+'-'+tag)).claim.id;
    try {
      await store.onboardMerchant(identity,{merchant_id:merchantA.id,verified_display_name:'Alpha'});
      await store.onboardMerchant(identity,{merchant_id:merchantB.id,verified_display_name:'Beta'});
      const contactA=await store.createContact(merchantA,{name:'Customer A',phone:phoneA});
      const contactB=await store.createContact(merchantB,{name:'Customer B',phone:phoneA});
      const other=await store.createContact(merchantA,{name:'Other Customer',phone:phoneB});
      const debt=await claim(merchantA,contactA,'20000','YER','debt','debt');
      const payment=await claim(merchantA,contactA,'10000','YER','payment','payment');
      const usd=await claim(merchantB,contactB,'5.2501','USD','debt','usd');
      const pendingRejected=await claim(merchantA,contactA,'15000','YER','debt','rejected');
      const foreignId=await claim(merchantA,other,'99999','YER','debt','foreign');
      await store.verifyPhone(identity,{customer_id:customer.id,phone:phoneA,proof_reference:'fin14-proof-A-'+s});
      await store.verifyPhone(identity,{customer_id:foreign.id,phone:phoneB,proof_reference:'fin14-proof-B-'+s});
      const both=await store.listCustomerRelationships(customer,{});
      assert.equal(both.items.length,2);
      assert.ok(both.items.every(x=>x.status==='pending'));

      // A mixed-ownership batch must not partially approve the valid row.
      await assert.rejects(()=>store.decideClaimsBatch(customer,
        {decision:'accept',claim_ids:[debt,foreignId]}),{status:404});
      const raw=await pool.query(
        'SELECT count(*)::int AS n FROM customer_claim_decisions WHERE claim_id=$1',[debt]);
      assert.equal(raw.rows[0].n,0);

      const result=await store.decideClaimsBatch(customer,{
        claim_ids:[payment,usd,debt],decision:'accept'});
      assert.equal(result.selected_count,3);
      assert.equal(result.newly_recorded_count,3);
      assert.equal(result.newly_posted_count,0);
      assert.equal(result.totals_by_currency_and_type.find(
        x=>x.currency==='YER'&&x.type==='debt').total_amount,'20000.0000');
      assert.equal(result.totals_by_currency_and_type.find(
        x=>x.currency==='YER'&&x.type==='payment').total_amount,'10000.0000');
      assert.equal(result.totals_by_currency_and_type.find(
        x=>x.currency==='USD').total_amount,'5.2501');
      // Selecting a subset does not affect another pending claim.
      assert.equal((await store.claimsInbox(customer,{})).items.find(
        x=>x.claim_id===pendingRejected).stage,'awaiting_review');

      const replay=await store.decideClaimsBatch(customer,{
        claim_ids:[debt,payment,usd],decision:'accept'});
      assert.equal(replay.newly_recorded_count,0);
      assert.equal(replay.newly_posted_count,0);
      await assert.rejects(()=>store.decideClaimsBatch(customer,{
        claim_ids:[debt,payment],decision:'reject'}),{status:409});
      await assert.rejects(()=>store.decideClaimsBatch(customer,{
        claim_ids:[debt,debt],decision:'accept'}),{status:422});

      // A rejected request + a valid request in one transaction: all rollback.
      const anotherPending=await claim(merchantA,contactA,'3','SAR','debt','fresh');
      await store.decideClaim(customer,pendingRejected,{decision:'reject'});
      await assert.rejects(()=>store.decideClaimsBatch(customer,{
        claim_ids:[anotherPending,pendingRejected],decision:'accept'}),{status:409});
      assert.equal((await store.claimsInbox(customer,{})).items.find(
        x=>x.claim_id===anotherPending).stage,'awaiting_review');

      for(const row of both.items) {
        await store.decideRelationship(customer,row.relationship_id,{decision:'accept'});
      }
      const aRel=both.items.find(x=>x.merchant_id===merchantA.id);
      const bRel=both.items.find(x=>x.merchant_id===merchantB.id);
      const aBalance=await store.ledger.balances(customer,aRel.relationship_id);
      const bBalance=await store.ledger.balances(customer,bRel.relationship_id);
      assert.equal(aBalance.currencies.find(x=>x.currency==='YER').balance,'10000.0000');
      assert.equal(bBalance.currencies.find(x=>x.currency==='USD').balance,'5.2501');
      const posted=await pool.query(
        'SELECT count(*)::int AS n FROM financial_movements WHERE source_claim_id=ANY($1::uuid[])',
        [[debt,payment,usd]]);
      assert.equal(posted.rows[0].n,3);
      await assert.rejects(()=>store.decideClaimsBatch(foreign,{
        claim_ids:[debt,payment],decision:'accept'}),{status:404});
    }finally{await pool.end();}
  });
