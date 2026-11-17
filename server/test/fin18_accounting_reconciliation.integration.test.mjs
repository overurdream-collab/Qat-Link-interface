import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';
import { createApi } from '../src/http.mjs';

const url=process.env.FIN08_TEST_DATABASE_URL;
function adenToday(){
  const parts=Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Aden',
    year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
  const get=x=>parts.find(p=>p.type===x).value;
  return get('year')+'-'+get('month')+'-'+get('day');
}
const jsonPost=(body,extra={})=>({method:'POST',
  headers:{'content-type':'application/json',...extra},body:JSON.stringify(body)});

test('FIN-18 PostgreSQL/API E2E: off-app partial consent, currency reconciliation, delegation, race and settlements',
  {skip:!url},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin18-accounting-regression-long-test-secret'});
    const suffix=randomUUID().slice(0,8);
    const merchant={id:'fin18-m-'+suffix,role:'merchant'};
    const customer={id:'fin18-c-'+suffix,role:'customer'};
    const stranger={id:'fin18-x-'+suffix,role:'customer'};
    const identity={id:'identity-fin18',role:'identity_service'};
    const phone='+96777'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const key=x=>'fin18-'+suffix+'-'+x;
    const tokens=new Map([['Bearer merchant',merchant],['Bearer customer',customer],
      ['Bearer stranger',stranger],['Bearer identity',identity]]);
    const api=createApi({store,verify:header=>tokens.get(header)||null});
    await new Promise(resolve=>api.listen(0,'127.0.0.1',resolve));
    const base='http://127.0.0.1:'+api.address().port;
    const call=(actor,path,options={})=>fetch(base+path,{
      ...options,headers:{authorization:'Bearer '+actor,...options.headers}
    });
    try{
      await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Synthetic reconciliation shop'});
      const contact=await store.createContact(merchant,{name:'Synthetic outside-app customer',phone});
      const createClaim=async(name,amount,type,unit)=>
        store.createClaim(merchant,{contact_id:contact.id,amount,type,currency:unit},key(name));
      const debtY=await createClaim('debt-yer','100.2500','debt','YER');
      const paymentY=await createClaim('payment-yer','40.1250','payment','YER');
      const debtS=await createClaim('debt-sar','15.0005','debt','SAR');
      await createClaim('pending-payment-sar','5.0001','payment','SAR');
      const debtU=await createClaim('debt-usd','2.1234','debt','USD');
      const duplicate=await createClaim('debt-yer','100.2500','debt','YER');
      assert.equal(duplicate.replayed,true);
      assert.equal((await store.claimsInbox(customer,{})).items.length,0);
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('proof')});
      assert.equal((await store.claimsInbox(customer,{})).items.length,5);
      const relation=(await store.listCustomerRelationships(customer,{})).items[0];
      assert.equal(relation.status,'pending');
      for(const claim of [debtY.claim,paymentY.claim,debtS.claim,debtU.claim]){
        const decision=await store.decideClaim(customer,claim.id,{decision:'accept'});
        assert.equal(decision.ledger_posted,false);
      }
      await store.decideRelationship(customer,relation.relationship_id,{decision:'accept'});
      let merchantBalances=(await store.ledger.balances(merchant,relation.relationship_id)).currencies;
      let customerBalances=(await store.ledger.balances(customer,relation.relationship_id)).currencies;
      const expected=new Map([['YER','60.1250'],['SAR','15.0005'],['USD','2.1234']]);
      for(const [code,balance] of expected){
        assert.equal(merchantBalances.find(x=>x.currency===code).balance,balance);
        assert.equal(customerBalances.find(x=>x.currency===code).balance,balance);
      }
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE relationship_id=$1',
        [relation.relationship_id])).rows[0].n,4);
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE source_claim_id=$1',
        [debtY.claim.id])).rows[0].n,1);

      const pendingSar=await store.ledger.pendingStatement(customer,relation.relationship_id,
        {currency:'SAR',from:adenToday(),to:adenToday()});
      assert.equal(pendingSar.pending_debts,'0.0000');
      assert.equal(pendingSar.pending_payments,'5.0001');
      assert.equal(pendingSar.items.length,1);
      assert.equal(pendingSar.items[0].source,'merchant_claim');

      const oldDebt=await store.ledger.createOperation(merchant,relation.relationship_id,
        {type:'debt',amount:'1.0001',currency:'YER'},key('pre-delegation'));
      assert.equal(oldDebt.status,'pending');
      assert.equal((await store.ledger.setAutoApproval(customer,relation.relationship_id,{enabled:true})).version,1);
      const autoDebt=await store.ledger.createOperation(merchant,relation.relationship_id,
        {type:'debt',amount:'2.0002',currency:'YER'},key('delegated-debt'));
      assert.equal(autoDebt.status,'approved');
      assert.equal(autoDebt.approval_method,'delegated_policy');
      const customerPayment=await store.ledger.createOperation(customer,relation.relationship_id,
        {type:'payment',amount:'3.0001',currency:'YER'},key('manual-payment'));
      assert.equal(customerPayment.status,'pending');
      assert.equal((await store.ledger.setAutoApproval(customer,relation.relationship_id,{enabled:false})).version,2);
      const postDisableDebt=await store.ledger.createOperation(merchant,relation.relationship_id,
        {type:'debt',amount:'4.0001',currency:'YER'},key('after-disable'));
      assert.equal(postDisableDebt.status,'pending');
      const decisions=await Promise.all([
        store.ledger.decideOperation(customer,relation.relationship_id,oldDebt.operation_id,{decision:'accept'}),
        store.ledger.decideOperation(customer,relation.relationship_id,oldDebt.operation_id,{decision:'accept'})
      ]);
      assert.equal(decisions.filter(x=>x.ledger_posted).length,1);
      assert.equal(decisions.filter(x=>x.replayed).length,1);
      const autoMovement=await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE source_operation_id=$1',
        [autoDebt.operation_id]);
      assert.equal(autoMovement.rows[0].n,1);
      expected.set('YER','63.1253');
      merchantBalances=(await store.ledger.balances(merchant,relation.relationship_id)).currencies;
      customerBalances=(await store.ledger.balances(customer,relation.relationship_id)).currencies;
      assert.equal(merchantBalances.find(x=>x.currency==='YER').balance,expected.get('YER'));
      assert.equal(customerBalances.find(x=>x.currency==='YER').balance,expected.get('YER'));

      const pendingY=await store.ledger.pendingStatement(merchant,relation.relationship_id,
        {currency:'YER',from:adenToday(),to:adenToday()});
      assert.equal(pendingY.pending_debts,'4.0001');
      assert.equal(pendingY.pending_payments,'3.0001');
      assert.equal(pendingY.items.length,2);
      const debtMovement=(await pool.query(
        'SELECT id FROM financial_movements WHERE source_claim_id=$1',[debtY.claim.id])).rows[0].id;
      const paymentMovement=(await pool.query(
        'SELECT id FROM financial_movements WHERE source_claim_id=$1',[paymentY.claim.id])).rows[0].id;

      const allocationPath='/v1/relationships/'+relation.relationship_id+'/payment-allocations';
      const allocationResponse=await call('merchant',allocationPath,
        jsonPost({action:'allocate',payment_movement_id:paymentMovement,debt_movement_id:debtMovement,amount:'30.0001'},
          {'idempotency-key':key('http-allocation')}));
      assert.equal(allocationResponse.status,201);
      const allocation=await allocationResponse.json();
      const consent=await call('customer',allocationPath+'/'+allocation.request_id+'/decision',
        jsonPost({decision:'accept'}));
      assert.equal(consent.status,200);
      const allocationView=await call('customer',allocationPath+'?payment_movement_id='+paymentMovement);
      assert.equal(allocationView.status,200);
      const allocationSnapshot=await allocationView.json();
      assert.equal(allocationSnapshot.allocated_amount,'30.0001');
      assert.equal(allocationSnapshot.unallocated_credit,'10.1249');
      assert.equal((await store.ledger.balances(customer,relation.relationship_id)).currencies
        .find(x=>x.currency==='YER').balance,'63.1253');

      const requestA=await store.settlements.request(customer,relation.relationship_id,
        {action:'allocate',payment_movement_id:paymentMovement,debt_movement_id:debtMovement,amount:'6.0000'},key('race-a'));
      const requestB=await store.settlements.request(merchant,relation.relationship_id,
        {action:'allocate',payment_movement_id:paymentMovement,debt_movement_id:debtMovement,amount:'6.0000'},key('race-b'));
      const race=await Promise.allSettled([
        store.settlements.decide(merchant,relation.relationship_id,requestA.request_id,{decision:'accept'}),
        store.settlements.decide(customer,relation.relationship_id,requestB.request_id,{decision:'accept'})
      ]);
      assert.equal(race.filter(x=>x.status==='fulfilled').length,1);
      assert.equal(race.filter(x=>x.status==='rejected'&&x.reason.status===409).length,1);
      await assert.rejects(()=>store.ledger.requestReversal(customer,relation.relationship_id,
        {movement_id:debtMovement,reason:'Release allocation before reversing'},key('blocked-reversal')),{status:409});

      const winnerId=race[0].status==='fulfilled'?requestA.request_id:requestB.request_id;
      const winnerCreator=race[0].status==='fulfilled'?customer:merchant;
      const releaseActor=winnerCreator.role==='customer'?customer:merchant;
      const releaseApprover=releaseActor.role==='customer'?merchant:customer;
      const release=await store.settlements.request(releaseActor,relation.relationship_id,
        {action:'release',allocation_id:winnerId,payment_movement_id:paymentMovement,
          debt_movement_id:debtMovement,amount:'6.0000'},key('release-race-winner'));
      await store.settlements.decide(releaseApprover,relation.relationship_id,release.request_id,{decision:'accept'});
      const fullRelease=await store.settlements.request(customer,relation.relationship_id,
        {action:'release',allocation_id:allocation.request_id,payment_movement_id:paymentMovement,
          debt_movement_id:debtMovement,amount:'30.0001'},key('release-first-allocation'));
      await store.settlements.decide(merchant,relation.relationship_id,fullRelease.request_id,{decision:'accept'});
      const reversal=await store.ledger.requestReversal(customer,relation.relationship_id,
        {movement_id:debtMovement,reason:'Approved reversal after releases'},key('approved-reversal'));
      await store.ledger.decideOperation(merchant,relation.relationship_id,reversal.operation_id,{decision:'accept'});
      expected.set('YER','-37.1247');
      merchantBalances=(await store.ledger.balances(merchant,relation.relationship_id)).currencies;
      customerBalances=(await store.ledger.balances(customer,relation.relationship_id)).currencies;
      assert.equal(merchantBalances.find(x=>x.currency==='YER').balance,expected.get('YER'));
      assert.equal(customerBalances.find(x=>x.currency==='YER').balance,expected.get('YER'));
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE source_operation_id=$1',
        [reversal.operation_id])).rows[0].n,1);

      for(const actor of ['merchant','customer']){
        const response=await call(actor,'/v1/relationships/'+relation.relationship_id+'/balances');
        assert.equal(response.status,200);
        const result=await response.json();
        for(const [code,balance] of expected)
          assert.equal(result.currencies.find(x=>x.currency===code).balance,balance);
      }
      const strangerRead=await call('stranger','/v1/relationships/'+relation.relationship_id+'/balances');
      assert.equal(strangerRead.status,404);
      const pendingHttp=await call('customer','/v1/relationships/'+relation.relationship_id+
        '/pending-statement?currency=YER&from='+adenToday()+'&to='+adenToday());
      assert.equal(pendingHttp.status,200);
      assert.equal((await pendingHttp.json()).pending_payments,'3.0001');
    }finally{
      await new Promise(resolve=>api.close(resolve));
      await pool.end();
    }
  });
