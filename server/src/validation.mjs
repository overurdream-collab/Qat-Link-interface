import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}
export const invalid = (message) => new ApiError(422, 'invalid_input', message);
export function assertText(value, name, max = 255) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) throw invalid(`${name} is required or too long`);
  return value.trim();
}
export function uuid(value, name = 'id') {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) throw invalid(`${name} must be a UUID`);
  return value.toLowerCase();
}
export function normalizePhone(input) {
  if (typeof input !== 'string') throw invalid('phone is required');
  const stripped = input.replace(/[\s\-()]/g, '');
  const phone = /^7\d{8}$/.test(stripped) ? `+967${stripped}` : /^00967\d{9}$/.test(stripped) ? `+${stripped.slice(2)}` : stripped;
  if (!/^\+[1-9]\d{8,14}$/.test(phone)) throw invalid('phone must be E.164 or a nine-digit Yemen mobile');
  return phone;
}
export function money(value) {
  // Never convert financial amounts to Number or binary floating point.
  if (typeof value !== 'string' || !/^(?!0+(?:\.0+)?$)\d{1,16}(?:\.\d{1,4})?$/.test(value)) throw invalid('amount must be a positive decimal string, up to four fractional digits');
  const [whole, decimals = ''] = value.split('.');
  return `${BigInt(whole)}${decimals ? `.${decimals.replace(/0+$/, '') || '0'}` : ''}`;
}
export function currency(value) {
  if (!['YER', 'SAR', 'USD'].includes(value)) throw invalid('unsupported currency');
  return value;
}
export function decision(value) {
  if (value !== 'accept' && value !== 'reject') throw invalid('decision must be accept or reject');
  return value;
}
export function idempotencyKey(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_.:-]{8,128}$/.test(value)) throw invalid('Idempotency-Key must be 8-128 safe characters');
  return value;
}
export function claimDigest({contactId, amount, currency: unit, description}) {
  return createHash('sha256').update(JSON.stringify([contactId, amount, unit, description ?? ''])).digest('hex');
}
export function page(value) {
  if (value === undefined || value === null) return 50;
  const n = Number(value);
  if (!/^\d+$/.test(String(value)) || !Number.isSafeInteger(n) || n < 1 || n > 100) throw invalid('limit must be from 1 to 100');
  return n;
}
export function encodeCursor(payload, secret) {
  const raw = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = createHmac('sha256', secret).update(raw).digest('base64url');
  return `${raw}.${sig}`;
}
export function decodeCursor(encoded, secret) {
  if (!encoded) return null;
  if (typeof encoded !== 'string' || encoded.length > 1500) throw invalid('invalid cursor');
  const [raw, sig, ...extra] = encoded.split('.');
  const expected = createHmac('sha256', secret).update(raw).digest('base64url');
  // Compare authenticated cursor signatures without leaking equality timing.
  if (!raw || !sig || extra.length || sig.length !== expected.length) throw invalid('invalid cursor');
  if (!timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) throw invalid('invalid cursor');
  try {
    const cursor = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (typeof cursor.snapshot !== 'string' || !Number.isFinite(Date.parse(cursor.snapshot)) ||
        typeof cursor.createdAt !== 'string' || !Number.isFinite(Date.parse(cursor.createdAt))) throw new Error('cursor');
    uuid(cursor.id, 'cursor id');
    return cursor;
  } catch { throw invalid('invalid cursor'); }
}