import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const url=process.env.FIN08_TEST_DATABASE_URL;
function adenToday(){
  const parts=Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Aden',
    year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
  const get=x=>parts.find(p=>p.type===x).value;
  return get('year')+'-'+get('month')+'-'+get('day');
}
test('FIN-13 PostgreSQL: legacy debts+payments, bilateral approval, exact ledger and customer credit',
  {skip:!url},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin13-integrated-verified-very-long-test-secret'});
    const suffix=randomUUID().slice(0,8);
    const merchant={id:'fin13-m-'+suffix,role:'merchant'};
    const customer={id:'fin13-c-'+suffix,role:'customer'};
    const stranger={id:'fin13-x-'+suffix,role:'customer'};
    const identity={id:'trusted-id-fin13',role:'identity_service'};
    const phone='+96777'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const key=x=>'fin13-'+suffix+'-'+x;
    try {
      await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Trusted shop'});
      const contact=await store.createContact(merchant,{name:'Historical debtor',phone});
      const claim=async(name,amount,type='debt',currency='YER')=>
        (await store.createClaim(merchant,{contact_id:contact.id,amount,currency,type},key(name))).claim;
      const debt1=await claim('debt1','20000');
      const debt2=await claim('debt2','15000');
      const payment=await claim('payment','10000','payment');
      assert.equal(payment.type,'payment');
      await assert.rejects(()=>store.createClaim(merchant,{contact_id:contact.id,amount:'10000',
        currency:'YER',type:'debt'},key('payment')),{status:409});
      const before=(await store.summary(merchant)).currencies.find(x=>x.currency==='YER');
      assert.equal(before.outside_app,'35000.0000');
      assert.equal(before.outside_app_payments,'10000.0000');
      assert.match(before.approved_from_claims,/^0(?:\.0+)?$/);
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('proof')});
      const inbox=await store.claimsInbox(customer,{});
      assert.deepEqual(new Set(inbox.items.map(x=>x.claim_id)),
        new Set([debt1.id,debt2.id,payment.id]));
      assert.equal(inbox.items.find(x=>x.claim_id===payment.id).type,'payment');
      const rel=(await store.listCustomerRelationships(customer,{})).items[0];
      assert.equal(rel.status,'pending');
      const a=await store.decideClaim(customer,debt1.id,{decision:'accept'});
      const p=await store.decideClaim(customer,payment.id,{decision:'accept'});
      assert.equal(a.ledger_posted,false);
      assert.equal(p.ledger_posted,false);
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE merchant_id=$1',
        [merchant.id])).rows[0].n,0);
      await store.decideRelationship(customer,rel.relationship_id,{decision:'accept'});
      const approved=(await store.ledger.balances(merchant,rel.relationship_id)).currencies;
      assert.equal(approved.find(x=>x.currency==='YER').approved_debts,'20000.0000');
      assert.equal(approved.find(x=>x.currency==='YER').approved_payments,'10000.0000');
      assert.equal(approved.find(x=>x.currency==='YER').balance,'10000.0000');
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'10000.0000');
      assert.equal((await store.summary(merchant)).currencies.find(x=>x.currency==='YER')
        .awaiting_customer_or_relationship,'15000.0000');
      await store.decideClaim(customer,debt1.id,{decision:'accept'});
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE merchant_id=$1',
        [merchant.id])).rows[0].n,2);
      await assert.rejects(()=>store.ledger.balances(stranger,rel.relationship_id),{status:404});

      // A new payment created by the customer needs the merchant's own approval.
      const pay2=await store.ledger.createOperation(customer,rel.relationship_id,
        {type:'payment',amount:'20000.0000',currency:'YER'},key('registered-payment'));
      assert.equal(pay2.status,'pending');
      assert.equal(pay2.ledger_posted,false);
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies.find(x=>x.currency==='YER').balance,'10000.0000');
      await assert.rejects(()=>store.ledger.decideOperation(customer,rel.relationship_id,
        pay2.operation_id,{decision:'accept'}),{status:403});
      const pm=await store.ledger.decideOperation(merchant,rel.relationship_id,
        pay2.operation_id,{decision:'accept'});
      assert.equal(pm.ledger_posted,true);
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'-10000.0000');
      await store.ledger.decideOperation(merchant,rel.relationship_id,pay2.operation_id,{decision:'accept'});
      await assert.rejects(()=>store.ledger.createOperation(customer,rel.relationship_id,
        {type:'payment',amount:'999',currency:'YER'},key('registered-payment')),{status:409});

      // Manual pending debt stays pending even after customer enables future auto-approval.
      const old=await store.ledger.createOperation(merchant,rel.relationship_id,
        {type:'debt',amount:'7.0001',currency:'USD'},key('old-pending'));
      assert.equal(old.status,'pending');
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='USD').balance,'0.0000');
      const enable=await store.ledger.setAutoApproval(customer,rel.relationship_id,{enabled:true});
      assert.equal(enable.enabled,true);
      assert.equal(enable.version,1);
      const auto=await store.ledger.createOperation(merchant,rel.relationship_id,
        {type:'debt',amount:'2.0001',currency:'USD'},key('auto-debt'));
      assert.equal(auto.status,'approved');
      assert.equal(auto.approval_method,'delegated_policy');
      assert.equal(auto.auto_policy_version,1);
      assert.equal(auto.ledger_posted,true);
      assert.equal((await store.ledger.operations(customer,rel.relationship_id,{limit:100})).items
        .find(x=>x.id===old.operation_id).status,'pending');
      const pendingPayment=await store.ledger.createOperation(merchant,rel.relationship_id,
        {type:'payment',amount:'1',currency:'USD'},key('not-auto-payment'));
      assert.equal(pendingPayment.status,'pending');
      const disabled=await store.ledger.setAutoApproval(customer,rel.relationship_id,{enabled:false});
      assert.equal(disabled.version,2);
      const manual=await store.ledger.createOperation(merchant,rel.relationship_id,
        {type:'debt',amount:'3',currency:'USD'},key('post-disabled'));
      assert.equal(manual.status,'pending');
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='USD').balance,'2.0001');
      await store.ledger.decideOperation(customer,rel.relationship_id,old.operation_id,{decision:'reject'});
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='USD').balance,'2.0001');
      await store.ledger.decideOperation(customer,rel.relationship_id,manual.operation_id,{decision:'accept'});
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='USD').balance,'5.0001');

      // Correct approved debt with a NEW opposite-sign movement, not an UPDATE.
      const original=(await pool.query('SELECT id FROM financial_movements WHERE source_claim_id=$1',
        [debt1.id])).rows[0].id;
      const reversal=await store.ledger.requestReversal(customer,rel.relationship_id,
        {movement_id:original,reason:'Customer and merchant agreed to reverse'},key('reversal'));
      assert.equal(reversal.status,'pending');
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'-10000.0000');
      await store.ledger.decideOperation(merchant,rel.relationship_id,reversal.operation_id,{decision:'accept'});
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'-30000.0000');
      await assert.rejects(()=>store.ledger.requestReversal(customer,rel.relationship_id,
        {movement_id:original,reason:'Another reversal'},key('reversal2')),{status:409});
      await assert.rejects(()=>pool.query('UPDATE financial_movements SET amount=999 WHERE id=$1',
        [original]),/immutable/i);

      const statement=await store.ledger.statement(customer,rel.relationship_id,
        {currency:'YER',from:adenToday(),to:adenToday()});
      assert.equal(statement.opening_balance,'0.0000');
      assert.equal(statement.closing_balance,'-30000.0000');
      assert.equal(statement.approved_debts,'20000.0000');
      assert.equal(statement.approved_payments,'50000.0000');
      assert.equal(statement.items.length,4);
      const first=await store.ledger.operations(customer,rel.relationship_id,{limit:1});
      assert.equal(first.items.length,1);
      assert.ok(first.next_cursor);
      const second=await store.ledger.operations(customer,rel.relationship_id,{limit:1,cursor:first.next_cursor});
      assert.equal(second.items.length,1);
      assert.notEqual(first.items[0].id,second.items[0].id);
      await assert.rejects(()=>store.ledger.operations(stranger,rel.relationship_id,{limit:1,cursor:first.next_cursor}),{status:422});
      await assert.rejects(()=>store.ledger.statement(merchant,rel.relationship_id,
        {currency:'YER',from:'2026-11-30',to:'2026-01-01'}),{status:422});

      await store.revokeProof(identity,{proof_reference:key('proof')});
      await assert.rejects(()=>store.ledger.balances(customer,rel.relationship_id),{status:404});
      assert.equal((await store.ledger.balances(merchant,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'-30000.0000');
    } finally {await pool.end();}
  });
