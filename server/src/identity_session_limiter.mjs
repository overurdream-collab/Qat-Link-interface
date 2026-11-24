// Defensive per-peer request budget for the Identity HTTP service.
// Only the TCP peer address is accepted: untrusted Forwarded/X-Forwarded-For is ignored.
// This is a single-process safety net, NOT an edge-level distributed rate limiter.
export function createIdentitySessionLimiter({
  limit = 60,
  windowMs = 60_000,
  maxPeers = 4096,
  clock = Date.now,
} = {}) {
  if (![limit, windowMs, maxPeers].every(v => Number.isSafeInteger(v) && v > 0) ||
      typeof clock !== 'function') {
    throw new TypeError('Invalid identity rate-limit configuration');
  }

  const peers = new Map();
  function check(peer) {
    const now = clock();
    const address = (typeof peer === 'string' && peer.length > 0 && peer.length <= 128)
      ? peer : 'unknown';

    let entry = peers.get(address);
    if (entry && now >= entry.resetAt) {
      peers.delete(address);
      entry = undefined;
    }

    if (!entry) {
      // Purge stale entries before bounding memory. Do not evict active entries,
      // since that would give an attacker a simple rate-limit bypass.
      if (peers.size >= maxPeers) {
        for (const [key, value] of peers) {
          if (now >= value.resetAt) peers.delete(key);
        }
      }
      if (peers.size >= maxPeers) return { allowed: false, retryAfterSeconds: 1 };
      peers.set(address, { count: 1, resetAt: now + windowMs });
      return { allowed: true, retryAfterSeconds: 0 };
    }
    if (entry.count >= limit) {
      return {
        allowed: false,
        retryAfterSeconds: Math.max(1, Math.ceil((entry.resetAt - now) / 1000)),
      };
    }
    entry.count++;
    return { allowed: true, retryAfterSeconds: 0 };
  }

  return { check };
}
