import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const url=process.env.FIN08_TEST_DATABASE_URL;
test('FIN-14 cross-merchant selection and mixed debt/payment decisions are atomic and isolated',
 {skip:!url},async()=>{
  const {Pool}=await import('pg');
  const pool=new Pool({connectionString:url});
  const store=new Fin08Store(pool,{cursorSecret:'fin14-multiple-merchants-atomic-consent-secret'});
  const s=randomUUID().slice(0,8);
  const m1={id:'b14a-'+s,role:'merchant'};
  const m2={id:'b14b-'+s,role:'merchant'};
  const customer={id:'b14c-'+s,role:'customer'};
  const other={id:'b14x-'+s,role:'customer'};
  const identity={id:'trusted-identity-fin14',role:'identity_service'};
  const p1='+96771'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
  const p2='+96773'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
  const key=x=>'b14-'+s+'-'+x;
  const claim=async(m,c,type,amount,unit,part)=>
    (await store.createClaim(m,{contact_id:c.id,type,amount,currency:unit},key(part))).claim.id;
  const select=(id,dec='accept')=>({id,decision:dec});
  try{
    await store.onboardMerchant(identity,{merchant_id:m1.id,verified_display_name:'Shop one'});
    await store.onboardMerchant(identity,{merchant_id:m2.id,verified_display_name:'Shop two'});
    const c1=await store.createContact(m1,{name:'Customer at first shop',phone:p1});
    const c2=await store.createContact(m2,{name:'Customer at second shop',phone:p1});
    const c3=await store.createContact(m1,{name:'Unrelated customer',phone:p2});
    const debt=await claim(m1,c1,'debt','20000','YER','d');
    const payment=await claim(m1,c1,'payment','10000','YER','p');
    const usd=await claim(m2,c2,'debt','5.2501','USD','u');
    const foreign=await claim(m1,c3,'debt','25000','YER','f');
    await store.verifyPhone(identity,{customer_id:customer.id,phone:p1,proof_reference:key('pr1')});
    await store.verifyPhone(identity,{customer_id:other.id,phone:p2,proof_reference:key('pr2')});
    // A foreign phone proof means ALL selected decisions fail, not partial success.
    await assert.rejects(()=>store.batch.decideHistoricalClaims(customer,{
      decisions:[select(debt),select(foreign)]}),{status:404});
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM customer_claim_decisions WHERE claim_id=$1',
      [debt])).rows[0].n,0);

    const accepted=await store.batch.decideHistoricalClaims(customer,{decisions:[
      select(debt),select(payment),select(usd,'reject')
    ]});
    assert.equal(accepted.scope,'selected_claims_only');
    assert.equal(accepted.newly_posted_count,0);
    assert.equal(accepted.reviewed_by_currency.find(x=>x.currency==='YER').selected_debts,'20000.0000');
    assert.equal(accepted.reviewed_by_currency.find(x=>x.currency==='YER').selected_payments,'10000.0000');
    assert.equal(accepted.reviewed_by_currency.find(x=>x.currency==='YER').selected_net_estimate,'10000.0000');
    assert.equal(accepted.reviewed_by_currency.find(x=>x.currency==='USD').selected_debts,'5.2501');
    const again=await store.batch.decideHistoricalClaims(customer,{decisions:[
      select(payment),select(debt),select(usd,'reject')
    ]});
    assert.ok(again.items.every(x=>x.replayed));
    assert.equal(again.newly_posted_count,0);
    await assert.rejects(()=>store.batch.decideHistoricalClaims(customer,{
      decisions:[select(debt,'reject'),select(payment,'accept')]}),{status:409});
    const links=await store.listCustomerRelationships(customer,{});
    assert.equal(links.items.length,2);
    assert.ok(links.items.every(x=>x.status==='pending'));
    for(const r of links.items)await store.decideRelationship(customer,r.relationship_id,{decision:'accept'});
    const rel1=links.items.find(x=>x.merchant_id===m1.id).relationship_id;
    const rel2=links.items.find(x=>x.merchant_id===m2.id).relationship_id;
    assert.equal((await store.ledger.balances(customer,rel1)).currencies.find(
      x=>x.currency==='YER').balance,'10000.0000');
    assert.equal((await store.ledger.balances(customer,rel2)).currencies.find(
      x=>x.currency==='USD').balance,'0.0000');

    // Modern operations: mixed creators cannot be mass-approved by one actor.
    const mDebt=await store.ledger.createOperation(m1,rel1,
      {type:'debt',amount:'2.0001',currency:'USD'},key('modern-debt'));
    const cPayment=await store.ledger.createOperation(customer,rel1,
      {type:'payment',amount:'5.0000',currency:'SAR'},key('modern-payment'));
    await assert.rejects(()=>store.batch.decideRelationshipOperations(customer,rel1,{
      decisions:[select(mDebt.operation_id),select(cPayment.operation_id)]}),{status:403});
    assert.equal((await store.ledger.balances(customer,rel1)).currencies.find(
      x=>x.currency==='USD').balance,'0.0000');
    await store.batch.decideRelationshipOperations(customer,rel1,{
      decisions:[select(mDebt.operation_id)]});
    await store.batch.decideRelationshipOperations(m1,rel1,{
      decisions:[select(cPayment.operation_id)]});
    const after=await store.ledger.balances(customer,rel1);
    assert.equal(after.currencies.find(x=>x.currency==='USD').balance,'2.0001');
    assert.equal(after.currencies.find(x=>x.currency==='SAR').balance,'-5.0000');
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements '+
      'WHERE source_claim_id=ANY($1::uuid[]) OR source_operation_id=ANY($2::uuid[])',
      [[debt,payment,usd],[mDebt.operation_id,cPayment.operation_id]])).rows[0].n,4);
  }finally{await pool.end();}
});
