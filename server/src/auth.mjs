import { createVerify } from 'node:crypto';
import { ApiError } from './validation.mjs';

// In production tokens MUST be issued by the trusted identity provider only
// after its actual OTP/device proof flow. This API does not mint tokens or OTPs.
export function createVerifier({ publicKey, issuer, audience, maxAgeSeconds = 3600 }) {
  if (!publicKey || !issuer || !audience) throw new Error('Verified JWT issuer/audience/public key are mandatory');
  return (authorization) => {
    if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) throw new ApiError(401, 'unauthorized', 'Authentication required');
    const token = authorization.slice(7);
    const chunks = token.split('.');
    if (chunks.length !== 3 || chunks.some((c) => !/^[\w-]+$/.test(c))) throw new ApiError(401, 'unauthorized', 'Invalid session');
    let header; let claims;
    try {
      header = JSON.parse(Buffer.from(chunks[0], 'base64url'));
      claims = JSON.parse(Buffer.from(chunks[1], 'base64url'));
    } catch { throw new ApiError(401, 'unauthorized', 'Invalid session'); }
    if (header?.alg !== 'RS256' || (header.typ && header.typ !== 'JWT')) throw new ApiError(401, 'unauthorized', 'Invalid session');
    const verifier = createVerify('RSA-SHA256');
    verifier.update(`${chunks[0]}.${chunks[1]}`);
    verifier.end();
    if (!verifier.verify(publicKey, Buffer.from(chunks[2], 'base64url'))) throw new ApiError(401, 'unauthorized', 'Invalid session');
    const now = Math.floor(Date.now() / 1000);
    if (claims.iss !== issuer || claims.aud !== audience ||
        !Number.isInteger(claims.iat) || !Number.isInteger(claims.exp) ||
        claims.iat > now + 30 || claims.exp <= now || claims.nbf > now + 30 ||
        claims.exp - claims.iat > maxAgeSeconds ||
        !['merchant', 'customer', 'identity_service'].includes(claims.role) ||
        typeof claims.sub !== 'string' || !claims.sub.trim() || claims.sub.length > 200) {
      throw new ApiError(401, 'unauthorized', 'Invalid or expired session');
    }
    return { id: claims.sub, role: claims.role };
  };
}
export function requireRole(actor, role) {
  if (actor?.role !== role) throw new ApiError(403, 'forbidden', 'Not permitted');
}