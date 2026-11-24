import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,createSign} from 'node:crypto';
import {createVerifier} from '../src/auth.mjs';

const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
const verifier=createVerifier({publicKey:publicKey.export({type:'spki',format:'pem'}),issuer:'fin25-test-issuer',audience:'fin25-test-audience'});
function token(role,issuer='fin25-test-issuer'){
 const now=Math.floor(Date.now()/1000);
 const header=Buffer.from(JSON.stringify({alg:'RS256',typ:'JWT'})).toString('base64url');
 const payload=Buffer.from(JSON.stringify({iss:issuer,aud:'fin25-test-audience',sub:'identity-test',role,iat:now,exp:now+120})).toString('base64url');
 const s=createSign('RSA-SHA256');s.update(header+'.'+payload);s.end();
 return 'Bearer '+header+'.'+payload+'.'+s.sign(privateKey).toString('base64url');
}
test('identity service RS256 JWT is accepted by trusted verifier',()=>assert.equal(verifier(token('identity_service')).role,'identity_service'));
test('merchant JWT does not grant identity service role',()=>assert.notEqual(verifier(token('merchant')).role,'identity_service'));
test('wrong issuer is rejected',()=>assert.throws(()=>verifier(token('identity_service','attacker'))));
test('tampered JWT is rejected',()=>assert.throws(()=>verifier(token('identity_service')+'A')));
