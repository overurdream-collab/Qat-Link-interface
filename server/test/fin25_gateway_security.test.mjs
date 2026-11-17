import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, createSign } from 'node:crypto';
import { fingerprint, createChallenge, challengePayload, canonicalRequest, verifyRsa, validateSignedMetadata, SIGNATURE_WINDOW_MS } from '../src/gateway_device_crypto.mjs';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 3072 });
const pem = publicKey.export({ format: 'pem', type: 'spki' });
function sign(message) {
  const s = createSign('RSA-SHA256');
  s.update(message);
  s.end();
  return s.sign(privateKey).toString('base64');
}
test('gateway challenge is random and 32 bytes', () => {
  const a = createChallenge(), b = createChallenge();
  assert.notEqual(a, b);
  assert.equal(Buffer.from(a, 'base64url').length, 32);
});
test('gateway enrollment proof binds device and challenge', () => {
  const payload = challengePayload('device-a', createChallenge());
  assert.equal(verifyRsa(pem, payload, sign(payload)), true);
  assert.equal(verifyRsa(pem, payload.replace('device-a', 'device-b'), sign(payload)), false);
});
test('gateway request signature binds method, path, nonce and exact body', () => {
  const timestamp = String(Date.now()), nonce = 'unique-nonce-0123456789';
  const payload = canonicalRequest('POST', '/v1/gateway/poll', timestamp, nonce, '{"x":1}');
  const sig = sign(payload);
  assert.equal(verifyRsa(pem, payload, sig), true);
  for (const changed of [
    canonicalRequest('GET', '/v1/gateway/poll', timestamp, nonce, '{"x":1}'),
    canonicalRequest('POST', '/v1/gateway/result', timestamp, nonce, '{"x":1}'),
    canonicalRequest('POST', '/v1/gateway/poll', timestamp, 'different-nonce-012345', '{"x":1}'),
    canonicalRequest('POST', '/v1/gateway/poll', timestamp, nonce, '{"x":2}')
  ]) assert.equal(verifyRsa(pem, changed, sig), false);
});
test('gateway rejects malformed signatures and weak keys', () => {
  assert.equal(verifyRsa(pem, 'payload', '!invalid!'), false);
  const weak = generateKeyPairSync('rsa', { modulusLength: 2048 }).publicKey.export({ format:'pem', type:'spki' });
  assert.throws(() => fingerprint(weak));
});
test('gateway rejects stale, future and malformed signed metadata', () => {
  const now = Date.now(), nonce = 'unique-nonce-0123456789';
  assert.doesNotThrow(() => validateSignedMetadata({ timestamp:String(now), nonce, now }));
  assert.throws(() => validateSignedMetadata({ timestamp:String(now-SIGNATURE_WINDOW_MS-1), nonce, now }));
  assert.throws(() => validateSignedMetadata({ timestamp:String(now+SIGNATURE_WINDOW_MS+1), nonce, now }));
  assert.throws(() => validateSignedMetadata({ timestamp:String(now), nonce:'short', now }));
  assert.throws(() => validateSignedMetadata({ timestamp:'abc', nonce, now }));
});
