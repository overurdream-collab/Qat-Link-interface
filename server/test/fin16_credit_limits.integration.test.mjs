import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const url=process.env.FIN08_TEST_DATABASE_URL;
test('FIN-16: merchant currency limits block only new debts, retain pending risk and audited versioning',
  {skip:!url},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin16-credit-limit-currency-verified-test-secret'});
    const suffix=randomUUID().slice(0,8);
    const merchant={id:'fin16-merchant-'+suffix,role:'merchant'};
    const customer={id:'fin16-customer-'+suffix,role:'customer'};
    const stranger={id:'fin16-other-'+suffix,role:'merchant'};
    const identity={id:'fin16-identity-service',role:'identity_service'};
    const phone='+96771'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const key=name=>'fin16-'+suffix+'-'+name;
    try{
      await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Credit ledger'});
      await store.onboardMerchant(identity,{merchant_id:stranger.id,verified_display_name:'Other ledger'});
      const contact=await store.createContact(merchant,{name:'Credit customer',phone});
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('proof')});
      const rel=(await store.listCustomerRelationships(customer,{})).items[0];
      await store.decideRelationship(customer,rel.relationship_id,{decision:'accept'});
      const id=rel.relationship_id;
      const operation=async(actor,type,amount,unit,name)=>
        store.ledger.createOperation(actor,id,
          {type,amount,currency:unit},key(name));

      const d=await operation(merchant,'debt','600','YER','first-debt');
      await store.ledger.decideOperation(customer,id,d.operation_id,{decision:'accept'});
      const p=await operation(customer,'payment','200','YER','paid');
      await store.ledger.decideOperation(merchant,id,p.operation_id,{decision:'accept'});
      assert.equal((await store.ledger.balances(customer,id)).currencies.find(
        x=>x.currency==='YER').balance,'400.0000');

      // Pending risk includes both registered debt and historic merchant claims,
      // but never alters the authoritative approved ledger.
      const pending=await operation(merchant,'debt','50','YER','unapproved');
      await store.createClaim(merchant,{
        contact_id:contact.id,type:'debt',amount:'100',currency:'YER'},key('historic-risk'));
      let snap=await store.credit.getSnapshot(customer,id);
      let yer=snap.currencies.find(x=>x.currency==='YER');
      assert.equal(snap.scope,'approved_ledger_and_separate_unapproved_exposure');
      assert.equal(yer.approved_balance,'400.0000');
      assert.equal(yer.pending_debts,'150.0000');
      assert.equal(yer.pending_net_estimate,'150.0000');
      assert.equal(yer.enabled,false);

      // Customer/stranger cannot change the merchant's limit.
      await assert.rejects(()=>store.credit.setPolicy(customer,id,{
        currency:'YER',enabled:true,limit_amount:'500',mode:'block'}),{status:403});
      await assert.rejects(()=>store.credit.setPolicy(stranger,id,{
        currency:'YER',enabled:true,limit_amount:'500',mode:'block'}),{status:404});
      const policy=await store.credit.setPolicy(merchant,id,{
        currency:'YER',enabled:true,limit_amount:'500',mode:'block'});
      assert.equal(policy.enabled,true);
      assert.equal(policy.version,1);
      assert.equal(policy.limit_amount,'500.0000');
      const repeated=await store.credit.setPolicy(merchant,id,{
        currency:'YER',enabled:true,limit_amount:'500.0000',mode:'block'});
      assert.equal(repeated.replayed,true);
      assert.equal(repeated.version,1);

      await assert.rejects(()=>operation(merchant,'debt','100.0001','YER','over-limit'),{
        status:409,code:'credit_limit_exceeded'});
      assert.equal((await store.ledger.balances(customer,id)).currencies.find(
        x=>x.currency==='YER').balance,'400.0000');
      const exact=await operation(merchant,'debt','100','YER','at-limit');
      assert.equal(exact.status,'pending');
      assert.equal(exact.credit_warning,null);
      snap=await store.credit.getSnapshot(merchant,id);
      yer=snap.currencies.find(x=>x.currency==='YER');
      assert.equal(yer.pending_debts,'250.0000');
      assert.equal(yer.approved_balance,'400.0000');
      assert.equal(yer.approved_exceeds_limit,false);
      assert.equal((await store.ledger.operations(customer,id,{})).items
        .find(x=>x.id===pending.operation_id).status,'pending');

      // Warning mode never blocks, and SAR exposure is completely independent
      // of YER and USD; exact currency scales remain strings.
      const sarPolicy=await store.credit.setPolicy(merchant,id,{
        currency:'SAR',enabled:true,limit_amount:'5.0000',mode:'warn'});
      assert.equal(sarPolicy.version,1);
      const warned=await operation(merchant,'debt','7.2501','SAR','sar-warning');
      assert.equal(warned.status,'pending');
      assert.equal(warned.credit_warning.mode,'warn');
      assert.equal(warned.credit_warning.projected_balance,'7.2501');
      assert.equal(warned.credit_warning.approved_balance,'0.0000');
      await store.ledger.decideOperation(customer,id,warned.operation_id,{decision:'accept'});
      const sar=(await store.credit.getSnapshot(customer,id)).currencies.find(x=>x.currency==='SAR');
      assert.equal(sar.approved_balance,'7.2501');
      assert.equal(sar.approved_exceeds_limit,true);

      // Block applies before an automatically approved new debt as well.
      await store.ledger.setAutoApproval(customer,id,{enabled:true});
      await assert.rejects(()=>operation(merchant,'debt','101','YER','auto-over-limit'),{
        status:409,code:'credit_limit_exceeded'});
      const usd=await operation(merchant,'debt','4.0001','USD','usd-allowed');
      assert.equal(usd.status,'approved');
      assert.equal(usd.ledger_posted,true);
      assert.equal((await store.credit.getSnapshot(customer,id)).currencies.find(
        x=>x.currency==='USD').approved_balance,'4.0001');

      // Payments always remain possible while a debt limit blocks new requests.
      const repay=await operation(customer,'payment','500','YER','positive-credit');
      assert.equal(repay.status,'pending');
      await store.ledger.decideOperation(merchant,id,repay.operation_id,{decision:'accept'});
      assert.equal((await store.credit.getSnapshot(customer,id)).currencies.find(
        x=>x.currency==='YER').approved_balance,'-100.0000');

      // Zero limit is allowed. Stored policy versions are never reset by disable.
      const zero=await store.credit.setPolicy(merchant,id,{
        currency:'YER',enabled:true,limit_amount:'0',mode:'block'});
      assert.equal(zero.version,2);
      const affordable=await operation(merchant,'debt','50','YER','part-credit');
      assert.equal(affordable.status,'approved');
      assert.equal((await store.ledger.balances(customer,id)).currencies.find(
        x=>x.currency==='YER').balance,'-50.0000');
      await assert.rejects(()=>operation(merchant,'debt','51','YER','exceed-zero'),{
        status:409,code:'credit_limit_exceeded'});
      const disable=await store.credit.setPolicy(merchant,id,{
        currency:'YER',enabled:false});
      assert.equal(disable.enabled,false);
      assert.equal(disable.version,3);
      assert.equal((await store.credit.setPolicy(merchant,id,{
        currency:'YER',enabled:false})).replayed,true);
      assert.equal((await store.credit.getSnapshot(customer,id)).currencies.find(
        x=>x.currency==='YER').limit_amount,null);
      const after=await operation(merchant,'debt','500','YER','policy-disabled');
      assert.equal(after.status,'approved');
      const audit=await pool.query('SELECT action,version FROM relationship_credit_limit_events WHERE relationship_id=$1 AND currency=$2 ORDER BY version',
        [id,'YER']);
      assert.deepEqual(audit.rows.map(x=>[x.action,x.version]),
        [['set',1],['set',2],['disable',3]]);
      const unrelated=(await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE relationship_id=$1',
        [id])).rows[0].n;
      assert.ok(unrelated>=5);
    }finally{await pool.end();}
  });
