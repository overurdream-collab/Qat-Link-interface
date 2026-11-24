// Per-account application-level budget for financial proxy calls. This is a
// defence-in-depth guard behind authentication; a distributed edge limiter is
// still required when more than one identity instance serves traffic.
export function createIdentityFinanceLimiter({
  now = () => Date.now(),
  readPerMinute = 120,
  writePerMinute = 20,
  maxAccounts = 10_000,
  windowMs = 60_000,
} = {}) {
  for (const [name, value] of [['readPerMinute', readPerMinute],
    ['writePerMinute', writePerMinute], ['maxAccounts', maxAccounts],
    ['windowMs', windowMs]]) {
    if (!Number.isInteger(value) || value < 1) throw new TypeError('Invalid finance limiter setting: ' + name);
  }
  const buckets = new Map();
  function check(accountId, kind) {
    if (typeof accountId !== 'string' || !accountId) throw new TypeError('Account id required');
    if (kind !== 'read' && kind !== 'write') throw new TypeError('Unknown finance operation kind');
    const limit = kind === 'write' ? writePerMinute : readPerMinute;
    const at = now();
    const key = kind + ':' + accountId;
    let bucket = buckets.get(key);
    if (!bucket || at - bucket.startedAt >= windowMs) {
      bucket = { startedAt: at, count: 0 };
      buckets.delete(key);
      buckets.set(key, bucket);
      if (buckets.size > maxAccounts) {
        const oldest = buckets.keys().next().value;
        if (oldest !== undefined) buckets.delete(oldest);
      }
    }
    bucket.count += 1;
    if (bucket.count <= limit) return { allowed: true, remaining: limit - bucket.count };
    const retryAfterSeconds = Math.max(1, Math.ceil((bucket.startedAt + windowMs - at) / 1000));
    return { allowed: false, retryAfterSeconds };
  }
  return { check };
}
