import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createSign, generateKeyPairSync } from 'node:crypto';
import { createVerifier } from '../src/auth.mjs';
import { normalizePhone, money, currency, decision, idempotencyKey, encodeCursor, decodeCursor } from '../src/validation.mjs';

test('Yemeni local phone canonicalizes; international E.164 retained',()=>{
 assert.equal(normalizePhone('771 234 567'),'+967771234567');
 assert.equal(normalizePhone('+967 771 234 567'),'+967771234567');
 assert.throws(()=>normalizePhone('77123'));
});
test('money is DECIMAL text, never float; zero/negative/overflow blocked',()=>{
 assert.equal(money('0000012.3500'),'12.35');
 assert.equal(money('0.0001'),'0.0001');
 for(const bad of [0,1.5,'0','0.0000','-1','1e5','1.12345','10000000000000000']) assert.throws(()=>money(bad));
});
test('separate currency and independent decision only',()=>{
 for(const c of ['YER','SAR','USD']) assert.equal(currency(c),c);
 assert.throws(()=>currency('EUR'));
 assert.equal(decision('accept'),'accept');assert.throws(()=>decision('accept_all'));
 assert.throws(()=>idempotencyKey('x'));
});
test('signed cursor rejects tampering and cannot accept malformed payload',()=>{
 const key='A'.repeat(40);
 const cursor=encodeCursor({snapshot:new Date().toISOString(),createdAt:new Date().toISOString(),id:'7f8a945c-680c-440a-bbfa-7a6d7f36c9d9'},key);
 assert.equal(decodeCursor(cursor,key).id,'7f8a945c-680c-440a-bbfa-7a6d7f36c9d9');
 assert.throws(()=>decodeCursor(cursor.slice(0,-2)+'aa',key));
});
test('JWT verifies RS256 and rejects unsigned, wrong role and expired',()=>{
 const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 const verify=createVerifier({publicKey:publicKey.export({format:'pem',type:'spki'}),issuer:'test-issuer',audience:'qat-link'});
 const sign=(claims,algorithm='RS256')=>{
  const h=Buffer.from(JSON.stringify({alg:algorithm,typ:'JWT'})).toString('base64url');
  const p=Buffer.from(JSON.stringify(claims)).toString('base64url');
  const signer=createSign('RSA-SHA256');signer.update(`${h}.${p}`);signer.end();
  return `${h}.${p}.${signer.sign(privateKey).toString('base64url')}`;
 };
 const now=Math.floor(Date.now()/1000);
 const claims={iss:'test-issuer',aud:'qat-link',iat:now,exp:now+600,role:'customer',sub:'customer_1'};
 assert.deepEqual(verify(`Bearer ${sign(claims)}`),{id:'customer_1',role:'customer'});
 assert.throws(()=>verify(`Bearer ${sign({...claims,role:'admin'})}`));
 assert.throws(()=>verify(`Bearer ${sign({...claims,exp:now-1})}`));
 assert.throws(()=>verify(`Bearer ${sign(claims,'none')}`));
});