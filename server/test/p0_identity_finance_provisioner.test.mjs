import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,randomUUID} from 'node:crypto';
import {createFinanceProvisioner} from '../src/identity_finance_provisioner.mjs';
import {createVerifier} from '../src/auth.mjs';

const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
const signing={
  privateKey:privateKey.export({type:'pkcs8',format:'pem'}),
  issuer:'identity-test',audience:'finance-test',
  financeBaseUrl:'http://fin08:8080/'
};
const verify=createVerifier({publicKey:publicKey.export({type:'spki',format:'pem'}),
  issuer:signing.issuer,audience:signing.audience});
test('merchant provisioning requires identity-service signed token',async()=>{
  const logs=[];
  const api=createFinanceProvisioner({settings:signing,fetchImpl:async(url,opts)=>{
    logs.push({url,body:JSON.parse(opts.body),role:verify(opts.headers.authorization).role});
    return {ok:true,async json(){return {merchant_id:'merchant-1'};}};
  }});
  await api.provision({account:{subject:'merchant-1',role:'merchant',display_name:'متجر تجريبي'},phone:'+967771234567'});
  assert.equal(logs[0].url,'http://fin08:8080/v1/internal/merchant-profiles');
  assert.equal(logs[0].role,'identity_service');
  assert.deepEqual(logs[0].body,{merchant_id:'merchant-1',verified_display_name:'متجر تجريبي'});
});
test('customer provisioning binds stable proof reference and never approves relationship',async()=>{
  const proof=String(randomUUID()),calls=[];
  const api=createFinanceProvisioner({settings:signing,fetchImpl:async(url,opts)=>{
    calls.push({url,body:JSON.parse(opts.body)});
    return {ok:true,async json(){return {linked:false,conflict:false};}};
  }});
  await api.provision({account:{subject:'customer-1',role:'customer',finance_proof_reference:proof},phone:'+967771234567'});
  assert.equal(calls[0].url,'http://fin08:8080/v1/internal/verified-phones');
  assert.deepEqual(calls[0].body,{customer_id:'customer-1',phone:'+967771234567',proof_reference:proof});
});
test('conflicting ownership and financial errors fail closed',async()=>{
  const acc={subject:'customer-1',role:'customer',finance_proof_reference:String(randomUUID())};
  const conflict=createFinanceProvisioner({settings:signing,fetchImpl:async()=>({ok:true,async json(){return {linked:false,conflict:true};}})});
  await assert.rejects(conflict.provision({account:acc,phone:'+967771234567'}),e=>e.status===409);
  const unavailable=createFinanceProvisioner({settings:signing,fetchImpl:async()=>({ok:false,status:503})});
  await assert.rejects(unavailable.provision({account:acc,phone:'+967771234567'}),e=>e.status===503);
});
test('rejects unexpected finance identities or invalid roles',async()=>{
  const api=createFinanceProvisioner({settings:signing,fetchImpl:async()=>({ok:true,async json(){return {merchant_id:'different'};}})});
  await assert.rejects(api.provision({account:{subject:'merchant-1',role:'merchant',display_name:'تاجر'},phone:'+967771234567'}),e=>e.status===502);
  await assert.rejects(api.provision({account:{role:'identity_service'},phone:'+967771234567'}),e=>e.status===403);
});
