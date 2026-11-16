import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const databaseUrl=process.env.FIN08_TEST_DATABASE_URL;

test('FIN-15: customer amount amendment preserves historic original, blocks competing consent and posts only approved replacement',
 {skip:!databaseUrl},async()=>{
  const {Pool}=await import('pg');
  const pool=new Pool({connectionString:databaseUrl});
  const store=new Fin08Store(pool,{cursorSecret:'fin15-historical-amendment-integration-long-secret'});
  const suffix=randomUUID().slice(0,8);
  const merchant={id:'fin15-hm-'+suffix,role:'merchant'};
  const customer={id:'fin15-hc-'+suffix,role:'customer'};
  const stranger={id:'fin15-hx-'+suffix,role:'merchant'};
  const identity={id:'identity-for-fin15',role:'identity_service'};
  const phone='+96771'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
  const key=(name)=>'fin15-'+suffix+'-'+name;
  try{
    await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Historic shop'});
    await store.onboardMerchant(identity,{merchant_id:stranger.id,verified_display_name:'Wrong merchant'});
    const contact=await store.createContact(merchant,{name:'Pre-app customer',phone});
    const d1=(await store.createClaim(merchant,
      {contact_id:contact.id,type:'debt',amount:'20000',currency:'YER'},key('original-debt'))).claim;
    const d2=(await store.createClaim(merchant,
      {contact_id:contact.id,type:'debt',amount:'1000',currency:'YER'},key('second-debt'))).claim;
    const p=(await store.createClaim(merchant,
      {contact_id:contact.id,type:'payment',amount:'100',currency:'YER'},key('payment'))).claim;
    await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('proof')});

    await assert.rejects(()=>store.amendments.requestHistorical(customer,p.id,
      {proposed_amount:'50',reason:'Payments cannot be amended as debts'},key('pay-change')),
      {status:422});
    await assert.rejects(()=>store.amendments.requestHistorical(customer,d1.id,
      {proposed_amount:'20000.0000',reason:'No actual change'},key('no-op')),
      {status:422});

    const proposed=await store.amendments.requestHistorical(customer,d1.id,
      {proposed_amount:'18000.5000',reason:'The agreed units were fewer than recorded'},
      key('requested-change'));
    assert.equal(proposed.status,'pending');
    assert.equal(proposed.original_amount,'20000.0000');
    assert.equal(proposed.proposed_amount,'18000.5000');
    assert.equal((await store.claimsInbox(customer,{})).items.find(x=>x.claim_id===d1.id).stage,
      'amendment_pending');
    assert.equal((await store.ledger.balances(customer,
      (await store.listCustomerRelationships(customer,{})).items[0].relationship_id)).currencies
      .find(x=>x.currency==='YER').balance,'0.0000');
    await assert.rejects(()=>store.decideClaim(customer,d1.id,{decision:'accept'}),{status:409});
    await assert.rejects(()=>store.batch.decideHistoricalClaims(customer,{decisions:[
      {id:d1.id,decision:'accept'},{id:d2.id,decision:'accept'}
    ]}),{status:409});
    const unmodified=await pool.query('SELECT amount::text FROM merchant_claims WHERE id=$1',[d1.id]);
    assert.equal(unmodified.rows[0].amount,'20000.0000');
    assert.equal((await pool.query(
      'SELECT count(*)::int AS n FROM customer_claim_decisions WHERE claim_id=$1',[d2.id])).rows[0].n,0);
    await assert.rejects(()=>store.amendments.decideMerchant(stranger,proposed.amendment_id,
      {decision:'accept'}),{status:404});

    const accepted=await store.amendments.decideMerchant(merchant,proposed.amendment_id,
      {decision:'accept'});
    assert.equal(accepted.status,'accepted');
    assert.equal(accepted.ledger_posted,false);
    assert.ok(accepted.replacement_claim_id);
    const old=(await pool.query('SELECT amount::text,superseded_by_claim_id FROM merchant_claims WHERE id=$1',
      [d1.id])).rows[0];
    assert.equal(old.amount,'20000.0000');
    assert.equal(old.superseded_by_claim_id,accepted.replacement_claim_id);
    assert.equal((await store.claimsInbox(customer,{})).items.find(x=>x.claim_id===d1.id).stage,
      'superseded');
    await assert.rejects(()=>store.decideClaim(customer,d1.id,{decision:'accept'}),{status:409});
    const replay=await store.amendments.decideMerchant(merchant,proposed.amendment_id,
      {decision:'accept'});
    assert.equal(replay.replayed,true);
    const again=await store.amendments.requestHistorical(customer,d1.id,
      {proposed_amount:'18000.5000',reason:'The agreed units were fewer than recorded'},
      key('requested-change'));
    assert.equal(again.replayed,true);

    const rejectRequest=await store.amendments.requestHistorical(customer,d2.id,
      {proposed_amount:'500',reason:'I disagree with the second debt'},key('reject-proposal'));
    await store.amendments.decideMerchant(merchant,rejectRequest.amendment_id,{decision:'reject'});
    await store.decideClaim(customer,d2.id,{decision:'accept'});
    const relation=(await store.listCustomerRelationships(customer,{})).items[0];
    await store.decideRelationship(customer,relation.relationship_id,{decision:'accept'});
    const approved=await store.ledger.balances(customer,relation.relationship_id);
    assert.equal(approved.currencies.find(x=>x.currency==='YER').balance,'19000.5000');
    const rows=(await pool.query('SELECT source_claim_id,amount::text FROM financial_movements WHERE merchant_id=$1',
      [merchant.id])).rows;
    assert.equal(rows.length,2);
    assert.ok(rows.some(x=>x.source_claim_id===accepted.replacement_claim_id &&
      x.amount==='18000.5000'));
    assert.ok(!rows.some(x=>x.source_claim_id===d1.id));
    const policy=await store.ledger.setAutoApproval(customer,relation.relationship_id,{enabled:true});
    assert.equal(policy.enabled,true);
    assert.equal((await store.amendments.list(merchant,{})).items.length,2);
    assert.equal((await store.amendments.list(stranger,{})).items.length,0);
  }finally{await pool.end();}
});

test('FIN-15: modern pending debt amendment is mutually agreed and posted once, old movement never changes',
 {skip:!databaseUrl},async()=>{
  const {Pool}=await import('pg');
  const pool=new Pool({connectionString:databaseUrl});
  const store=new Fin08Store(pool,{cursorSecret:'fin15-modern-amendment-verified-customer-long-secret'});
  const suffix=randomUUID().slice(0,8);
  const merchant={id:'fin15-mm-'+suffix,role:'merchant'};
  const customer={id:'fin15-mc-'+suffix,role:'customer'};
  const identity={id:'identity-for-fin15',role:'identity_service'};
  const phone='+96777'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
  const key=name=>'modern-fin15-'+suffix+'-'+name;
  try{
    await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Merchant modern'});
    const contact=await store.createContact(merchant,{name:'Modern customer',phone});
    await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('proof')});
    const relationship=(await store.listCustomerRelationships(customer,{})).items[0];
    await store.decideRelationship(customer,relationship.relationship_id,{decision:'accept'});
    const relId=relationship.relationship_id;
    const newDebt=await store.ledger.createOperation(merchant,relId,
      {type:'debt',amount:'50.0000',currency:'SAR'},key('original'));
    assert.equal(newDebt.status,'pending');
    const proposed=await store.amendments.requestOperation(customer,relId,newDebt.operation_id,
      {proposed_amount:'47.2501',reason:'Correct number of bundles'},key('amend'));
    assert.equal(proposed.status,'pending');
    await assert.rejects(()=>store.ledger.decideOperation(customer,relId,newDebt.operation_id,
      {decision:'accept'}),{status:409});
    await assert.rejects(()=>store.batch.decideRelationshipOperations(customer,relId,{
      decisions:[{id:newDebt.operation_id,decision:'accept'}]}),{status:409});
    const current=await store.ledger.balances(customer,relId);
    assert.equal(current.currencies.find(x=>x.currency==='SAR').balance,'0.0000');
    const accepted=await store.amendments.decideMerchant(merchant,proposed.amendment_id,
      {decision:'accept'});
    assert.equal(accepted.status,'accepted');
    assert.equal(accepted.ledger_posted,true);
    assert.ok(accepted.replacement_operation_id);
    assert.equal((await store.ledger.balances(customer,relId)).currencies
      .find(x=>x.currency==='SAR').balance,'47.2501');
    const originals=await pool.query('SELECT amount::text,status FROM relationship_operations WHERE id=$1',
      [newDebt.operation_id]);
    assert.deepEqual(originals.rows[0],{amount:'50.0000',status:'superseded'});
    const linked=await pool.query(
      'SELECT replaces_operation_id,amount::text,status,approval_method FROM relationship_operations WHERE id=$1',
      [accepted.replacement_operation_id]);
    assert.deepEqual(linked.rows[0],{
      replaces_operation_id:newDebt.operation_id,amount:'47.2501',
      status:'approved',approval_method:'manual'
    });
    await assert.rejects(()=>store.ledger.decideOperation(customer,relId,newDebt.operation_id,
      {decision:'accept'}),{status:409});
    const replay=await store.amendments.decideMerchant(merchant,proposed.amendment_id,
      {decision:'accept'});
    assert.equal(replay.replayed,true);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE source_operation_id=$1',
      [accepted.replacement_operation_id])).rows[0].n,1);

    const another=await store.ledger.createOperation(merchant,relId,
      {type:'debt',amount:'5',currency:'USD'},key('another'));
    const second=await store.amendments.requestOperation(customer,relId,another.operation_id,
      {proposed_amount:'4',reason:'One item was not delivered'},key('second'));
    await store.amendments.decideMerchant(merchant,second.amendment_id,{decision:'reject'});
    const unchanged=(await pool.query('SELECT status,amount::text FROM relationship_operations WHERE id=$1',
      [another.operation_id])).rows[0];
    assert.deepEqual(unchanged,{status:'pending',amount:'5.0000'});
    await store.ledger.decideOperation(customer,relId,another.operation_id,{decision:'accept'});
    assert.equal((await store.ledger.balances(customer,relId)).currencies
      .find(x=>x.currency==='USD').balance,'5.0000');
  }finally{await pool.end();}
});
