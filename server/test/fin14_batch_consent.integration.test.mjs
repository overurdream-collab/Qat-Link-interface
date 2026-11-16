import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const url=process.env.FIN08_TEST_DATABASE_URL;
test('FIN-14 PostgreSQL selective batch consent: atomicity, tenant isolation, exact currencies and no prior auto-approval',
  {skip:!url},async()=>{
    const {Pool}=await import('pg');
    const pool=new Pool({connectionString:url});
    const store=new Fin08Store(pool,{cursorSecret:'fin14-batch-ci-only-strong-secret-123456789'});
    const suffix=randomUUID().slice(0,8);
    const merchant={id:'fin14-merchant-'+suffix,role:'merchant'};
    const other={id:'fin14-foreign-'+suffix,role:'merchant'};
    const customer={id:'fin14-customer-'+suffix,role:'customer'};
    const outsider={id:'fin14-outsider-'+suffix,role:'customer'};
    const identity={id:'trusted-identity-fin14',role:'identity_service'};
    const phone='+96777'+String(Math.floor(Math.random()*10000000)).padStart(7,'0');
    const key=x=>'fin14-'+suffix+'-'+x;
    try{
      await store.onboardMerchant(identity,{merchant_id:merchant.id,verified_display_name:'Primary merchant'});
      await store.onboardMerchant(identity,{merchant_id:other.id,verified_display_name:'Foreign merchant'});
      const contact=await store.createContact(merchant,{name:'Batch customer',phone});
      const claim=async(label,amount,type='debt',currency='YER')=>
        (await store.createClaim(merchant,{
          contact_id:contact.id,amount,currency,type},key(label))).claim;
      const d1=await claim('d1','20000');
      const d2=await claim('d2','15000');
      const p=await claim('p','10000','payment');
      await store.verifyPhone(identity,{customer_id:customer.id,phone,proof_reference:key('proof')});
      const rel=(await store.listCustomerRelationships(customer,{})).items[0];
      const accepted=await store.batch.decideHistoricalClaims(customer,{decisions:[
        {id:d1.id,decision:'accept'},{id:p.id,decision:'accept'}
      ]});
      assert.equal(accepted.scope,'selected_claims_only');
      assert.equal(accepted.newly_posted_count,0);
      assert.equal(accepted.reviewed_by_currency.find(x=>x.currency==='YER').selected_debts,'20000.0000');
      assert.equal(accepted.reviewed_by_currency.find(x=>x.currency==='YER').selected_payments,'10000.0000');
      assert.equal(accepted.reviewed_by_currency.find(x=>x.currency==='YER').selected_net_estimate,'10000.0000');
      await assert.rejects(()=>store.batch.decideHistoricalClaims(customer,{decisions:[
        {id:d2.id,decision:'accept'},{id:d2.id,decision:'reject'}
      ]}),{status:422});
      await assert.rejects(()=>store.batch.decideHistoricalClaims(outsider,{decisions:[
        {id:d2.id,decision:'accept'}
      ]}),{status:404});
      // A batch must roll back ALL changes if ANY choice conflicts.
      await assert.rejects(()=>store.batch.decideHistoricalClaims(customer,{decisions:[
        {id:d2.id,decision:'accept'},{id:d1.id,decision:'reject'}
      ]}),{status:409});
      const untouched=await pool.query('SELECT 1 FROM customer_claim_decisions WHERE claim_id=$1',[d2.id]);
      assert.equal(untouched.rowCount,0);
      await store.decideRelationship(customer,rel.relationship_id,{decision:'accept'});
      const initialBalance=await store.ledger.balances(customer,rel.relationship_id);
      assert.equal(initialBalance.forCurrency??undefined,undefined);
      assert.equal(initialBalance.currencies.find(x=>x.currency==='YER').balance,'10000.0000');
      const replay=await store.batch.decideHistoricalClaims(customer,{decisions:[
        {id:d1.id,decision:'accept'},{id:p.id,decision:'accept'}
      ]});
      assert.equal(replay.newly_posted_count,0);
      assert.ok(replay.items.every(x=>x.replayed));

      const op1=await store.ledger.createOperation(merchant,rel.relationship_id,
        {type:'debt',amount:'5.0001',currency:'USD'},key('usd-one'));
      const op2=await store.ledger.createOperation(merchant,rel.relationship_id,
        {type:'debt',amount:'7.0002',currency:'USD'},key('usd-two'));
      const pay=await store.ledger.createOperation(customer,rel.relationship_id,
        {type:'payment',amount:'3.0000',currency:'USD'},key('usd-pay'));
      assert.equal(op1.status,'pending');
      await assert.rejects(()=>store.batch.decideRelationshipOperations(merchant,rel.relationship_id,{
        decisions:[{id:op1.operation_id,decision:'accept'}]}),{status:403});
      await assert.rejects(()=>store.batch.decideRelationshipOperations(customer,rel.relationship_id,{
        decisions:[{id:op1.operation_id,decision:'accept'},{id:op1.operation_id,decision:'accept'}]}),{status:422});
      const foreignContact=await store.createContact(other,{name:'Same client',phone});
      const foreignRel=(await store.listCustomerRelationships(customer,{})).items
        .find(x=>x.merchant_id===other.id);
      assert.ok(foreignRel);
      await store.decideRelationship(customer,foreignRel.relationship_id,{decision:'accept'});
      const foreignOp=await store.ledger.createOperation(other,foreignRel.relationship_id,
        {type:'debt',amount:'55',currency:'USD'},key('foreign'));
      await assert.rejects(()=>store.batch.decideRelationshipOperations(customer,rel.relationship_id,{
        decisions:[{id:op1.operation_id,decision:'accept'},{id:foreignOp.operation_id,decision:'accept'}]
      }),{status:404});
      assert.equal((await store.ledger.operations(customer,rel.relationship_id,{})).items
        .find(x=>x.id===op1.operation_id).status,'pending');
      const result=await store.batch.decideRelationshipOperations(customer,rel.relationship_id,{
        decisions:[{id:op1.operation_id,decision:'accept'},{id:op2.operation_id,decision:'reject'}]
      });
      assert.equal(result.newly_posted_count,1);
      assert.equal(result.reviewed_by_currency.find(x=>x.currency==='USD').selected_debts,'12.0003');
      assert.equal((await store.ledger.balances(customer,rel.relationship_id)).currencies
        .find(x=>x.currency==='USD').balance,'5.0001');
      // The customer-created payment still needs independent merchant consent.
      assert.equal((await store.ledger.operations(customer,rel.relationship_id,{})).items
        .find(x=>x.id===pay.operation_id).status,'pending');
      const approvePayment=await store.batch.decideRelationshipOperations(merchant,rel.relationship_id,{
        decisions:[{id:pay.operation_id,decision:'accept'}]
      });
      assert.equal(approvePayment.newly_posted_count,1);
      assert.equal((await store.ledger.balances(merchant,rel.relationship_id)).currencies
        .find(x=>x.currency==='USD').balance,'2.0001');
      const repeat=await store.batch.decideRelationshipOperations(customer,rel.relationship_id,{
        decisions:[{id:op1.operation_id,decision:'accept'},{id:op2.operation_id,decision:'reject'}]
      });
      assert.equal(repeat.newly_posted_count,0);
      assert.ok(repeat.items.every(x=>x.replayed));
      await assert.rejects(()=>store.batch.decideRelationshipOperations(customer,rel.relationship_id,{
        decisions:[{id:op1.operation_id,decision:'reject'}]}),{status:409});
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM financial_movements WHERE source_operation_id=$1',
        [op1.operation_id])).rows[0].n,1);
      assert.ok(foreignContact.id);
    }finally{await pool.end();}
  });
