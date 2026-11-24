import test from 'node:test';
import assert from 'node:assert/strict';
import { createIdentityFinanceReadProxy } from '../src/identity_fin08_read_proxy.mjs';

const session='Bearer test-token-not-a-real-jwt';
const merchant={id:'merchant-1',role:'merchant'};
const customer={id:'customer-1',role:'customer'};

test('FIN08 read proxy: allows only role-owned GET routes, passes JWT unchanged',async()=>{
  const calls=[];
  const proxy=createIdentityFinanceReadProxy({
    financeBaseUrl:'http://fin08-private:8080/',
    fetchImpl:async (url,options)=>{
      calls.push({url:url.toString(),method:options.method,headers:options.headers});
      return new Response(JSON.stringify({items:[],next_cursor:null}),{
        status:200,headers:{'content-type':'application/json'}
      });
    }
  });
  assert.deepEqual(await proxy({method:'GET',url:'/v1/merchant/contacts?limit=5',
    authorization:session,account:merchant}),{items:[],next_cursor:null});
  assert.equal(calls.length,1);
  assert.equal(calls[0].url,'http://fin08-private:8080/v1/merchant/contacts?limit=5');
  assert.equal(calls[0].headers.authorization,session);
  assert.equal((await proxy({method:'GET',url:'/v1/customer/relationships',
    authorization:session,account:customer})).items.length,0);
  assert.equal(calls.length,2);
});

test('FIN08 read proxy: deny mutations, other roles, internal routes and query spoofing',async()=>{
  let calls=0;
  const proxy=createIdentityFinanceReadProxy({
    financeBaseUrl:'http://fin08-private:8080/',
    fetchImpl:async()=>{calls++;throw new Error('must never run')}
  });
  for(const args of [
    {method:'POST',url:'/v1/merchant/contacts',account:merchant},
    {method:'GET',url:'/v1/merchant/contacts',account:customer},
    {method:'GET',url:'/v1/internal/merchant-profiles',account:merchant},
    {method:'GET',url:'/v1/merchant/amendments',account:merchant},
    {method:'GET',url:'/v1/merchant/contacts?merchant_id=other',account:merchant},
    {method:'GET',url:'/v1/merchant/contacts/../../internal/merchant-profiles',account:merchant},
  ]) {
    await assert.rejects(proxy({ ...args, authorization:session }));
  }
  assert.equal(calls,0);
});

test('FIN08 read proxy: rejects missing authorization and prevents upstream leakage',async()=>{
  const proxy=createIdentityFinanceReadProxy({
    financeBaseUrl:'http://fin08-private:8080/',
    fetchImpl:async()=>new Response(JSON.stringify({error:'db_secret'}),{
      status:500,headers:{'content-type':'application/json'}
    }),
  });
  await assert.rejects(proxy({method:'GET',url:'/v1/customer/relationships',account:customer}),
    e=>e.status===401);
  await assert.rejects(proxy({method:'GET',url:'/v1/customer/relationships',
    authorization:session,account:customer}),
    e=>e.status===503 && !e.message.includes('db_secret'));
});
