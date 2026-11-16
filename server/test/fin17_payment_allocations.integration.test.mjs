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

test('FIN-17 PostgreSQL: bilateral allocations, unallocated credit, releases and reversal traceability',
  {skip:!url},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin17-allocation-verified-long-test-secret'});
    const suffix=randomUUID().slice(0,8);
    const merchant={id:'fin17-m-'+suffix,role:'merchant'};
    const customer={id:'fin17-c-'+suffix,role:'customer'};
    const identity={id:'identity-fin17',role:'identity_service'};
    const phone='+96777'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const key=x=>'fin17-'+suffix+'-'+x;
    try{
      await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Allocation shop'});
      const contact=await store.createContact(merchant,{name:'Settlement customer',phone});
      const debt=(await store.createClaim(merchant,{contact_id:contact.id,amount:'100',currency:'YER',type:'debt'},key('debt'))).claim;
      const payment=(await store.createClaim(merchant,{contact_id:contact.id,amount:'100',currency:'YER',type:'payment'},key('payment'))).claim;
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('proof')});
      const rel=(await store.listCustomerRelationships(customer,{})).items[0];
      await store.decideRelationship(customer,rel.relationship_id,{decision:'accept'});
      await store.decideClaim(customer,debt.id,{decision:'accept'});
      await store.decideClaim(customer,payment.id,{decision:'accept'});
      const pendingDebt=(await store.createClaim(merchant,{contact_id:contact.id,amount:'5.25',currency:'YER',type:'debt'},key('pending-debt'))).claim;
      const pendingPayment=await store.ledger.createOperation(customer,rel.relationship_id,
        {type:'payment',amount:'7.50',currency:'YER'},key('pending-payment'));
      assert.equal(pendingPayment.status,'pending');
      const pendingStatement=await store.ledger.pendingStatement(merchant,rel.relationship_id,
        {currency:'YER',from:adenToday(),to:adenToday()});
      assert.equal(pendingStatement.pending_debts,'5.2500');
      assert.equal(pendingStatement.pending_payments,'7.5000');
      assert.equal(pendingStatement.items.length,2);
      assert.equal(pendingStatement.scope,'unapproved_requests_only_not_an_account_balance');
      const movements=(await pool.query(
        'SELECT id,type FROM financial_movements WHERE relationship_id=$1',[rel.relationship_id])).rows;
      const debtMovement=movements.find(x=>x.type==='debt').id;
      const paymentMovement=movements.find(x=>x.type==='payment').id;
      const before=(await store.ledger.balances(merchant,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance;
      assert.equal(before,'0.0000');

      const first=await store.settlements.request(merchant,rel.relationship_id,{
        action:'allocate',payment_movement_id:paymentMovement,debt_movement_id:debtMovement,amount:'80'
      },key('allocate-80'));
      assert.equal(first.status,'pending');
      await assert.rejects(()=>store.settlements.decide(merchant,rel.relationship_id,first.request_id,
        {decision:'accept'}),{status:403});
      await store.settlements.decide(customer,rel.relationship_id,first.request_id,{decision:'accept'});
      let snapshot=await store.settlements.forPayment(customer,rel.relationship_id,paymentMovement);
      assert.equal(snapshot.allocated_amount,'80.0000');
      assert.equal(snapshot.unallocated_credit,'20.0000');
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'0.0000');
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE relationship_id=$1',
        [rel.relationship_id])).rows[0].n,2);

      await assert.rejects(()=>store.settlements.request(merchant,rel.relationship_id,{
        action:'allocate',payment_movement_id:paymentMovement,debt_movement_id:debtMovement,amount:'21'
      },key('overallocate')),{status:409});
      await assert.rejects(()=>store.ledger.requestReversal(customer,rel.relationship_id,
        {movement_id:debtMovement,reason:'Cannot reverse allocated debt'},key('reverse-allocated')),{status:409});

      const release=await store.settlements.request(customer,rel.relationship_id,{
        action:'release',allocation_id:first.request_id,payment_movement_id:paymentMovement,
        debt_movement_id:debtMovement,amount:'30'
      },key('release-30'));
      await store.settlements.decide(merchant,rel.relationship_id,release.request_id,{decision:'accept'});
      snapshot=await store.settlements.forPayment(merchant,rel.relationship_id,paymentMovement);
      assert.equal(snapshot.allocated_amount,'50.0000');
      assert.equal(snapshot.unallocated_credit,'50.0000');
      const second=await store.settlements.request(customer,rel.relationship_id,{
        action:'allocate',payment_movement_id:paymentMovement,debt_movement_id:debtMovement,amount:'40'
      },key('allocate-40'));
      await store.settlements.decide(merchant,rel.relationship_id,second.request_id,{decision:'accept'});
      snapshot=await store.settlements.forPayment(customer,rel.relationship_id,paymentMovement);
      assert.equal(snapshot.allocated_amount,'90.0000');
      assert.equal(snapshot.unallocated_credit,'10.0000');
      assert.equal(snapshot.history.length,3);

      const releaseFirst=await store.settlements.request(merchant,rel.relationship_id,{
        action:'release',allocation_id:first.request_id,payment_movement_id:paymentMovement,
        debt_movement_id:debtMovement,amount:'50'
      },key('release-first-rest'));
      await store.settlements.decide(customer,rel.relationship_id,releaseFirst.request_id,{decision:'accept'});
      const releaseSecond=await store.settlements.request(merchant,rel.relationship_id,{
        action:'release',allocation_id:second.request_id,payment_movement_id:paymentMovement,
        debt_movement_id:debtMovement,amount:'40'
      },key('release-second-rest'));
      await store.settlements.decide(customer,rel.relationship_id,releaseSecond.request_id,{decision:'accept'});
      snapshot=await store.settlements.forPayment(customer,rel.relationship_id,paymentMovement);
      assert.equal(snapshot.allocated_amount,'0.0000');
      assert.equal(snapshot.unallocated_credit,'100.0000');
      assert.equal(snapshot.history.length,5);

      const reversal=await store.ledger.requestReversal(customer,rel.relationship_id,
        {movement_id:debtMovement,reason:'Reverse after allocation release'},key('reverse-released'));
      await store.ledger.decideOperation(merchant,rel.relationship_id,reversal.operation_id,{decision:'accept'});
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'-100.0000');
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE relationship_id=$1',
        [rel.relationship_id])).rows[0].n,3);
      await assert.rejects(()=>pool.query(
        'UPDATE financial_payment_allocation_entries SET amount=1 WHERE request_id=$1',[first.request_id]),/immutable/i);
    }finally{await pool.end();}
  });
