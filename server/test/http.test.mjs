import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../src/http.mjs';

const merchant={id:'merchant-A',role:'merchant'};
const customer={id:'customer-B',role:'customer'};
const identity={id:'identity-service',role:'identity_service'};
const store={
  createContact:async(a,b)=>({merchant:a.id,name:b.name}),
  createClaim:async(a,b,key)=>({claim:{merchant:a.id,currency:b.currency,amount:b.amount,key},replayed:false}),
  claimsInbox:async(a)=>({items:[{claim_id:'previous-claim',customer:a.id}],next_cursor:null}),
  listCustomerRelationships:async(a)=>({items:[{relationship_id:'relation',customer:a.id}],next_cursor:null}),
  decideClaim:async(a,id,b)=>({customer:a.id,claim_id:id,decision:b.decision,ledger_posted:false}),
  listContacts:async(a)=>({items:[{contact_id:'sample',merchant:a.id}],next_cursor:null}),
  listContactClaims:async(a,id)=>({items:[{claim_id:'x',contact_id:id,merchant:a.id}],next_cursor:null}),
  summary:async(a)=>({currencies:[],merchant:a.id}),
  verifyPhone:async()=>({linked:true,conflict:false}),
  adjustments:{
    request:async(actor,id,body)=>({actor:actor.id,claim_id:id,proposed_amount:body.proposed_amount,status:'pending'}),
    decide:async(actor,id,body)=>({actor:actor.id,adjustment_id:id,decision:body.decision})
  }
};
const withApi=async(actor,action)=>{
 const server=createApi({store,verify:()=>actor});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{return await action(`http://127.0.0.1:${server.address().port}`);}
 finally{await new Promise(r=>server.close(r));}
};
const request=(base,path,options)=>fetch(`${base}${path}`,options);
const post=(data,headers={})=>({method:'POST',headers:{'content-type':'application/json',...headers},body:JSON.stringify(data)});
test('role separation: merchants cannot access previous claim inbox',async()=>{
 await withApi(merchant,async base=>{
  const r=await request(base,'/v1/customer/previous-claims'); assert.equal(r.status,403);
 });
});
test('customer inbox is derived from authenticated actor, not URL/customer ID',async()=>{
 await withApi(customer,async base=>{
  const r=await request(base,'/v1/customer/previous-claims?customer_id=attacker');
  assert.equal(r.status,200);
  assert.equal((await r.json()).items[0].customer,'customer-B');
 });
});
test('merchant claim requires JSON and does not perform automatic ledger posting',async()=>{
 await withApi(merchant,async base=>{
  const r=await request(base,'/v1/merchant/claims',post({contact_id:'some',currency:'YER',amount:'2500'}, {'Idempotency-Key':'claim-01-unique'}));
  assert.equal(r.status,201);
  const obj=await r.json();assert.equal(obj.merchant,'merchant-A');assert.equal(obj.ledger_posted,undefined);
 });
});
test('identity-only phone proof endpoint cannot be called as merchant or customer',async()=>{
 for(const actor of [merchant,customer]) await withApi(actor,async base=>{
  const r=await request(base,'/v1/internal/verified-phones',post({phone:'771234567'}));assert.equal(r.status,403);
 });
 await withApi(identity,async base=>{
  const r=await request(base,'/v1/internal/verified-phones',post({customer_id:'C',phone:'771234567',proof_reference:'otp-1'}));assert.equal(r.status,200);
 });
});
test('unauthenticated access is denied even with correct route',async()=>{
 await withApi(null,async base=>{
  const r=await request(base,'/v1/customer/previous-claims');assert.equal(r.status,403);
 });
});

test('merchant restoration list is scoped to verified actor and restricted to merchant role',async()=>{
  await withApi(merchant,async base=>{
    const r=await request(base,'/v1/merchant/contacts?merchant_id=attacker');
    assert.equal(r.status,200);
    assert.equal((await r.json()).items[0].merchant,'merchant-A');
    const detail=await request(base,'/v1/merchant/contacts/sample/claims');
    assert.equal(detail.status,200);
  });
  await withApi(customer,async base=>{
    const r=await request(base,'/v1/merchant/contacts');assert.equal(r.status,403);
    const detail=await request(base,'/v1/merchant/contacts/sample/claims');assert.equal(detail.status,403);
  });
});


test('relationship inbox belongs to authenticated customer, never merchant',async()=>{
  await withApi(customer,async base=>{
    const r=await request(base,'/v1/customer/relationships?customer_id=someone-else');
    assert.equal(r.status,200);
    assert.equal((await r.json()).items[0].customer,'customer-B');
  });
  await withApi(merchant,async base=>{
    const r=await request(base,'/v1/customer/relationships');assert.equal(r.status,403);
  });
});

test('FIN-15 amount proposals and merchant decisions use independent roles and verified actor IDs',async()=>{
  const requestPath='/v1/customer/previous-claims/00000000-0000-4000-8000-000000000001/amount-adjustment';
  const merchantPath='/v1/merchant/claim-adjustments/00000000-0000-4000-8000-000000000002/decision';
  await withApi(merchant,async base=>{
    const r=await request(base,requestPath,post({proposed_amount:'200',reason:'Correction'}));
    assert.equal(r.status,403);
  });
  await withApi(customer,async base=>{
    const r=await request(base,requestPath,post({
      proposed_amount:'200',reason:'Correction',customer_id:'spoofed'}));
    assert.equal(r.status,201);
    assert.equal((await r.json()).actor,customer.id);
    const blocked=await request(base,merchantPath,post({decision:'accept'}));
    assert.equal(blocked.status,403);
  });
  await withApi(merchant,async base=>{
    const r=await request(base,merchantPath,post({decision:'accept',merchant_id:'spoofed'}));
    assert.equal(r.status,200);
    assert.equal((await r.json()).actor,merchant.id);
  });
});
