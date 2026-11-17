import { createHash, createPublicKey, createVerify, randomBytes } from 'node:crypto';

export const CHALLENGE_TTL_MS = 120_000;
export const SIGNATURE_WINDOW_MS = 60_000;
export function normalizePublicKey(pem) {
  const key = createPublicKey(pem);
  if (key.asymmetricKeyType !== 'rsa' || key.asymmetricKeyDetails?.modulusLength < 3072)
    throw new Error('RSA 3072+ public key required');
  return key;
}
export function fingerprint(publicKeyPem) {
  const der = normalizePublicKey(publicKeyPem).export({type:'spki',format:'der'});
  return createHash('sha256').update(der).digest('hex');
}
export function createChallenge() {
  return randomBytes(32).toString('base64url');
}
export function challengePayload(deviceId, challenge) {
  return ['MAQWATI-GATEWAY-ENROLL-V1', deviceId, challenge].join('\n');
}
export function canonicalRequest(method, path, timestamp, nonce, rawBody) {
  return [method, path, timestamp, nonce, rawBody].join('\n');
}
export function verifyRsa(publicKeyPem, payload, signatureBase64) {
  if (typeof signatureBase64 !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(signatureBase64) || signatureBase64.length > 2048) return false;
  const sig = Buffer.from(signatureBase64,'base64');
  const verifier = createVerify('RSA-SHA256');
  verifier.update(payload,'utf8'); verifier.end();
  return verifier.verify(normalizePublicKey(publicKeyPem),sig);
}
export function validateSignedMetadata({timestamp,nonce,now=Date.now()}) {
  if (typeof timestamp !== 'string' || !/^\d{13}$/.test(timestamp) || Math.abs(now-Number(timestamp)) > SIGNATURE_WINDOW_MS) throw new Error('Invalid timestamp');
  if (typeof nonce !== 'string' || nonce.length < 16 || nonce.length > 128) throw new Error('Invalid nonce');
}
