import { IdentityError } from './identity_logic.mjs';

// Collect raw bytes before UTF-8 decoding: a multi-byte character may be split
// across stream chunks, and decoding each chunk independently corrupts JSON.
export async function readBody(req, limit) {
  const chunks = [];
  let length = 0;
  for await (const chunk of req) {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    length += bytes.length;
    if (length > limit) throw new IdentityError(413, 'Request too large');
    chunks.push(bytes);
  }
  return Buffer.concat(chunks).toString('utf8');
}
