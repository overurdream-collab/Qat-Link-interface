import test from 'node:test';
import assert from 'node:assert/strict';
import { createIdentityFinanceLimiter } from '../src/identity_finance_limiter.mjs';

test('finance limiter separates read and write budgets per account', () => {
  let at = 1_000_000;
  const limiter = createIdentityFinanceLimiter({
    now: () => at, readPerMinute: 2, writePerMinute: 1,
  });
  assert.equal(limiter.check('account-a', 'read').allowed, true);
  assert.equal(limiter.check('account-a', 'read').allowed, true);
  assert.equal(limiter.check('account-a', 'read').allowed, false);
  assert.equal(limiter.check('account-b', 'read').allowed, true);
  assert.equal(limiter.check('account-a', 'write').allowed, true);
  assert.equal(limiter.check('account-a', 'write').allowed, false);
  at += 60_000;
  assert.equal(limiter.check('account-a', 'read').allowed, true);
  assert.equal(limiter.check('account-a', 'write').allowed, true);
});

test('finance limiter returns a bounded retry-after and evicts old accounts', () => {
  let at = 5_000;
  const limiter = createIdentityFinanceLimiter({
    now: () => at, readPerMinute: 1, maxAccounts: 2,
  });
  assert.equal(limiter.check('a', 'read').allowed, true);
  assert.equal(limiter.check('b', 'read').allowed, true);
  assert.equal(limiter.check('c', 'read').allowed, true);
  const blocked = limiter.check('c', 'read');
  assert.equal(blocked.allowed, false);
  assert.ok(blocked.retryAfterSeconds >= 1 && blocked.retryAfterSeconds <= 60);
});

test('finance limiter rejects malformed settings and calls', () => {
  assert.throws(() => createIdentityFinanceLimiter({ readPerMinute: 0 }));
  assert.throws(() => createIdentityFinanceLimiter({ writePerMinute: 1.5 }));
  const limiter = createIdentityFinanceLimiter();
  assert.throws(() => limiter.check('', 'read'));
  assert.throws(() => limiter.check('a', 'delete'));
});
