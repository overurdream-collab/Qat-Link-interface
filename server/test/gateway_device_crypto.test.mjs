import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { fingerprint, createChallenge, challengePayload, canonicalRequest, verifyRsa, validateSignedMetadata } from '../src/gateway_device_crypto.mjs';

const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:3072});
const pem=publicKey.export({type:'spki',format:'pem'});
const signPayload=(s)=>sign('RSA-SHA256',Buffer.from(s),privateKey).toString('base64');
test('SPKI fingerprint is 64 lowercase hex',()=>assert.match(fingerprint(pem),/^[a-f0-9]{64}$/));
test('challenge proof binds device ID and random challenge',()=>{
 const c=createChallenge(),p=challengePayload('00000000-0000-4000-8000-000000000001',c);
 assert.equal(verifyRsa(pem,p,signPayload(p)),true);
 assert.equal(verifyRsa(pem,challengePayload('00000000-0000-4000-8000-000000000002',c),signPayload(p)),false);
 assert.equal(verifyRsa(pem,challengePayload('00000000-0000-4000-8000-000000000001',createChallenge()),signPayload(p)),false);
});
test('canonical HTTP signing rejects altered body and path',()=>{
 const p=canonicalRequest('POST','/v1/gateway/poll',String(Date.now()),'12345678-1234-1234-1234-123456789abc','{}');
 assert.equal(verifyRsa(pem,p,signPayload(p)),true);
 assert.equal(verifyRsa(pem,p.replace('/poll','/result'),signPayload(p)),false);
});
test('timestamp window and nonce validation',()=>{
 const now=Date.now();
 assert.doesNotThrow(()=>validateSignedMetadata({timestamp:String(now),nonce:'12345678-1234-1234-1234-123456789abc',now}));
 assert.throws(()=>validateSignedMetadata({timestamp:String(now-120000),nonce:'12345678-1234-1234-1234-123456789abc',now}));
 assert.throws(()=>validateSignedMetadata({timestamp:String(now),nonce:'short',now}));
});
