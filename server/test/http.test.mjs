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
  listMerchantRelationships:async(a)=>({items:[{relationship_id:'relation',merchant:a.id}],next_cursor:null}),
  decideClaim:async(a,id,b)=>({customer:a.id,claim_id:id,decision:b.decision,ledger_posted:false}),
  listContacts:async(a)=>({items:[{contact_id:'sample',merchant:a.id}],next_cursor:null}),
  listContactClaims:async(a,id)=>({items:[{claim_id:'x',contact_id:id,merchant:a.id}],next_cursor:null}),
  summary:async(a)=>({currencies:[],merchant:a.id}),
  amendments:{
    requestHistorical:async(actor,id,body,key)=>({actor:actor.id,id,amount:body.proposed_amount,key,status:'pending',replayed:false}),
    requestOperation:async(actor,rid,oid,body,key)=>({actor:actor.id,rid,oid,status:'pending',replayed:false}),
    decideMerchant:async(actor,id,body)=>({actor:actor.id,id,decision:body.decision,status:'accepted'}),
    list:async(actor)=>({items:[{actor:actor.id}],next_cursor:null})
  },
  verifyPhone:async()=>({linked:true,conflict:false})
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

test('merchant relationship list is scoped to the authenticated merchant only',async()=>{
  await withApi(merchant,async base=>{
    const r=await request(base,'/v1/merchant/relationships?merchant_id=attacker');
    assert.equal(r.status,200);
    assert.equal((await r.json()).items[0].merchant,'merchant-A');
  });
  await withApi(customer,async base=>{
    const r=await request(base,'/v1/merchant/relationships');assert.equal(r.status,403);
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

test('FIN-15 route ownership: only verified customer requests changes and only merchant responds',async()=>{
  const claimId='11111111-1111-4111-8111-111111111111';
  const amendId='22222222-2222-4222-8222-222222222222';
  const body={proposed_amount:'25.0001',reason:'Wrong quantity',customer_id:'spoofed'};
  await withApi(merchant,async base=>{
    const r=await request(base,'/v1/customer/previous-claims/'+claimId+'/amendments',
      post(body,{'Idempotency-Key':'fin15-test-request-01'}));
    assert.equal(r.status,403);
    const accepted=await request(base,'/v1/merchant/amendments/'+amendId+'/decision',
      post({decision:'accept'}));
    assert.equal(accepted.status,200);
    assert.equal((await accepted.json()).actor,merchant.id);
  });
  await withApi(customer,async base=>{
    const r=await request(base,'/v1/customer/previous-claims/'+claimId+'/amendments',
      post(body,{'Idempotency-Key':'fin15-test-request-01'}));
    assert.equal(r.status,201);
    const payload=await r.json();
    assert.equal(payload.actor,customer.id);
    assert.equal(payload.amount,'25.0001');
    assert.equal(payload.key,'fin15-test-request-01');
    const forbidden=await request(base,'/v1/merchant/amendments/'+amendId+'/decision',
      post({decision:'accept'}));
    assert.equal(forbidden.status,403);
    const inbox=await request(base,'/v1/customer/amendments');
    assert.equal(inbox.status,200);
    assert.equal((await inbox.json()).items[0].actor,customer.id);
  });
  await withApi(null,async base=>{
    const r=await request(base,'/v1/customer/previous-claims/'+claimId+'/amendments',
      post(body,{'Idempotency-Key':'fin15-test-request-01'}));
    assert.equal(r.status,403);
  });
});
