import test from 'node:test';
import assert from 'node:assert/strict';
import { createIdentitySessionLimiter } from '../src/identity_session_limiter.mjs';

test('per-peer limit denies excess requests with retry-after', () => {
  let now = 1000;
  const limiter = createIdentitySessionLimiter({ limit: 2, windowMs: 5000, clock: () => now });
  assert.equal(limiter.check('10.0.0.2').allowed, true);
  assert.equal(limiter.check('10.0.0.2').allowed, true);
  assert.deepEqual(limiter.check('10.0.0.2'), { allowed: false, retryAfterSeconds: 5 });
  now += 5000;
  assert.equal(limiter.check('10.0.0.2').allowed, true);
});

test('a separate peer has an independent budget', () => {
  const limiter = createIdentitySessionLimiter({ limit: 1 });
  assert.equal(limiter.check('192.0.2.1').allowed, true);
  assert.equal(limiter.check('192.0.2.1').allowed, false);
  assert.equal(limiter.check('192.0.2.2').allowed, true);
});

test('active key capacity is fail closed, not evicted for attackers', () => {
  let now = 0;
  const limiter = createIdentitySessionLimiter({ limit: 1, windowMs: 1000, maxPeers: 2, clock: () => now });
  assert.equal(limiter.check('peer-1').allowed, true);
  assert.equal(limiter.check('peer-2').allowed, true);
  assert.equal(limiter.check('peer-3').allowed, false);
  assert.equal(limiter.check('peer-1').allowed, false);
  now = 1000;
  assert.equal(limiter.check('peer-3').allowed, true);
});

test('missing peer address is bounded as unknown', () => {
  const limiter = createIdentitySessionLimiter({ limit: 1 });
  assert.equal(limiter.check(undefined).allowed, true);
  assert.equal(limiter.check('').allowed, false);
});

test('invalid limits fail startup rather than disabling defense', () => {
  assert.throws(() => createIdentitySessionLimiter({ limit: 0 }), TypeError);
  assert.throws(() => createIdentitySessionLimiter({ windowMs: -1 }), TypeError);
  assert.throws(() => createIdentitySessionLimiter({ maxPeers: 0 }), TypeError);
});
