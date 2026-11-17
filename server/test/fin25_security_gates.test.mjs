import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, createSign } from 'node:crypto';
import { createVerifier } from '../src/auth.mjs';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const verifier = createVerifier({
  publicKey: publicKey.export({ type: 'spki', format: 'pem' }),
  issuer: 'fin25-security-test',
  audience: 'fin25-identity',
});
const now = Math.floor(Date.now() / 1000);
function bearer(claimOverrides = {}, headerOverrides = {}) {
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT', ...headerOverrides })).toString('base64url');
  const claims = Buffer.from(JSON.stringify({
    iss: 'fin25-security-test', aud: 'fin25-identity', sub: 'identity-test',
    role: 'identity_service', iat: now - 10, exp: now + 120, ...claimOverrides,
  })).toString('base64url');
  const sign = createSign('RSA-SHA256');
  sign.update(header + '.' + claims);
  sign.end();
  return 'Bearer ' + header + '.' + claims + '.' + sign.sign(privateKey).toString('base64url');
}
test('FIN25 rejects missing or oversized bearer', () => {
  assert.throws(() => verifier(undefined));
  assert.throws(() => verifier('Bearer ' + 'x'.repeat(8193)));
});
test('FIN25 rejects algorithm confusion even with an RSA signature', () => {
  assert.throws(() => verifier(bearer({}, { alg: 'HS256' })));
  assert.throws(() => verifier(bearer({}, { alg: 'none' })));
});
test('FIN25 rejects untrusted issuer and audience', () => {
  assert.throws(() => verifier(bearer({ iss: 'attacker' })));
  assert.throws(() => verifier(bearer({ aud: 'wrong-service' })));
});
test('FIN25 rejects invalid token lifetime and numeric dates', () => {
  assert.throws(() => verifier(bearer({ exp: now - 1 })));
  assert.throws(() => verifier(bearer({ iat: String(now) })));
  assert.throws(() => verifier(bearer({ exp: now + 4000 })));
  assert.throws(() => verifier(bearer({ nbf: now + 300 })));
});
test('FIN25 rejects unsupported roles and missing subject', () => {
  assert.throws(() => verifier(bearer({ role: 'admin' })));
  assert.throws(() => verifier(bearer({ sub: '' })));
});
test('FIN25 accepts a correctly signed identity service token', () => {
  assert.equal(verifier(bearer()).role, 'identity_service');
});
