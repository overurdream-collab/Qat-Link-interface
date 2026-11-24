// Explicit allowlist for authenticated financial mutations. No arbitrary URL,
// method, query or header forwarding is possible from the public edge.
import { IdentityError } from './identity_logic.mjs';

const ID = '[a-f0-9-]{36}';
const routeRole = [
  { pattern: /^\/v1\/merchant\/contacts$/, roles: ['merchant'] },
  { pattern: /^\/v1\/merchant\/claims$/, roles: ['merchant'] },
  { pattern: /^\/v1\/merchant\/relationship-requests$/, roles: ['merchant'] },
  { pattern: new RegExp(`^/v1/customer/relationships/${ID}/decision$`, 'i'), roles: ['customer'] },
  { pattern: new RegExp(`^/v1/customer/relationships/${ID}/auto-approval$`, 'i'), roles: ['customer'] },
  { pattern: new RegExp(`^/v1/customer/previous-claims/${ID}/decision$`, 'i'), roles: ['customer'] },
  { pattern: /^\/v1\/customer\/previous-claims\/batch-decisions$/, roles: ['customer'] },
  { pattern: new RegExp(`^/v1/customer/previous-claims/${ID}/amendments$`, 'i'), roles: ['customer'] },
  { pattern: new RegExp(`^/v1/merchant/amendments/${ID}/decision$`, 'i'), roles: ['merchant'] },
  { pattern: new RegExp(`^/v1/relationships/${ID}/operations$`, 'i'), roles: ['merchant', 'customer'] },
  { pattern: new RegExp(`^/v1/relationships/${ID}/operations/${ID}/decision$`, 'i'), roles: ['merchant', 'customer'] },
  { pattern: new RegExp(`^/v1/relationships/${ID}/operations/batch-decisions$`, 'i'), roles: ['merchant', 'customer'] },
  { pattern: new RegExp(`^/v1/relationships/${ID}/operations/${ID}/amendments$`, 'i'), roles: ['merchant', 'customer'] },
  { pattern: new RegExp(`^/v1/relationships/${ID}/reversals$`, 'i'), roles: ['merchant', 'customer'] },
  { pattern: new RegExp(`^/v1/relationships/${ID}/credit-limits$`, 'i'), roles: ['merchant', 'customer'] },
];

const MAX_REQUEST_BYTES = 65_536;
const MAX_RESPONSE_BYTES = 512_000;

export function createIdentityFinanceWriteProxy({ fetchImpl, financeBaseUrl }) {
  if (typeof fetchImpl !== 'function') throw new TypeError('fetch required');
  const base = new URL(financeBaseUrl);
  if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password ||
      base.search || base.hash || base.pathname !== '/') {
    throw new TypeError('Invalid private FIN08 origin');
  }
  return async function writeFinance({ url, authorization, account, body, idempotencyKey }) {
    const path = new URL(url, 'http://localhost');
    if (path.search) throw new IdentityError(400, 'Invalid query');
    const match = routeRole.find(item => item.pattern.test(path.pathname));
    if (!match) throw new IdentityError(404, 'Not found');
    if (!account || !match.roles.includes(account.role)) throw new IdentityError(403, 'Role not allowed');
    if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) {
      throw new IdentityError(401, 'Authentication required');
    }
    if (typeof body !== 'string' || body.length === 0) throw new IdentityError(400, 'Invalid JSON');
    if (Buffer.byteLength(body, 'utf8') > MAX_REQUEST_BYTES) throw new IdentityError(413, 'Request too large');
    let parsed;
    try { parsed = JSON.parse(body); } catch { throw new IdentityError(400, 'Invalid JSON'); }
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new IdentityError(400, 'Invalid JSON');
    }
    const headers = { authorization, accept: 'application/json', 'content-type': 'application/json' };
    if (idempotencyKey !== undefined) {
      if (typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._:-]{1,128}$/.test(idempotencyKey)) {
        throw new IdentityError(400, 'Invalid idempotency key');
      }
      headers['idempotency-key'] = idempotencyKey;
    }
    const target = new URL(path.pathname, base);
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 8000);
    try {
      const result = await fetchImpl(target, {
        method: 'POST', headers, body, redirect: 'error', signal: abort.signal,
      });
      if (result.status === 401 || result.status === 403) {
        throw new IdentityError(result.status, 'FIN08 access denied');
      }
      if (result.status >= 500) throw new IdentityError(503, 'Financial service unavailable');
      const type = result.headers.get('content-type') || '';
      if (!type.toLowerCase().includes('application/json')) {
        throw new IdentityError(502, 'Invalid financial response');
      }
      const length = Number(result.headers.get('content-length'));
      if (Number.isFinite(length) && length > MAX_RESPONSE_BYTES) {
        throw new IdentityError(502, 'Response too large');
      }
      const reader = result.body?.getReader();
      if (!reader) throw new IdentityError(502, 'Invalid financial response');
      const parts = []; let size = 0;
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.length;
        if (size > MAX_RESPONSE_BYTES) {
          await reader.cancel();
          throw new IdentityError(502, 'Response too large');
        }
        parts.push(value);
      }
      const raw = Buffer.concat(parts).toString('utf8');
      let data; try { data = JSON.parse(raw); } catch { throw new IdentityError(502, 'Invalid financial response'); }
      if (!data || typeof data !== 'object' || Array.isArray(data)) {
        throw new IdentityError(502, 'Invalid financial response');
      }
      if (result.status >= 400 && result.status < 500) {
        const safe = { error: typeof data.error === 'string' ? data.error : 'request_failed' };
        if (typeof data.message === 'string') safe.message = data.message;
        return { status: result.status, data: safe };
      }
      if (result.status >= 200 && result.status < 300) return { status: result.status, data };
      throw new IdentityError(502, 'Invalid financial response');
    } catch (e) {
      if (e instanceof IdentityError) throw e;
      throw new IdentityError(503, 'Financial service unavailable');
    } finally { clearTimeout(timer); }
  };
}
