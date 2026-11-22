import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../src/http.mjs';

async function serve(verify) {
  const server = createApi({store: {}, verify});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const {port} = server.address();
  return {
    server,
    url: `http://127.0.0.1:${port}`,
    close: () => new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve())),
  };
}

test('HTTP security defaults are bounded and do not depend on a proxy', async () => {
  const t = await serve(() => ({id: 'safe-test', role: 'merchant'}));
  try {
    assert.equal(t.server.maxHeaderSize, 8192);
    assert.equal(t.server.headersTimeout, 10000);
    assert.equal(t.server.requestTimeout, 15000);
    assert.equal(t.server.keepAliveTimeout, 5000);
    assert.equal(t.server.maxRequestsPerSocket, 100);
    const res = await fetch(`${t.url}/healthz`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(res.headers.get('x-frame-options'), 'DENY');
    assert.equal(res.headers.get('referrer-policy'), 'no-referrer');
    assert.equal(res.headers.get('cache-control'), 'no-store, private');
    assert.match(res.headers.get('x-request-id'), /^[a-f0-9-]{36}$/);
    assert.match(res.headers.get('content-security-policy'), /default-src 'none'/);
  } finally {
    await t.close();
  }
});

test('request error response and incident logger never reveal sensitive details', async () => {
  const marker = 'phone-777123456-OTP-1234';
  const emitted = [];
  const original = console.error;
  const t = await serve(() => {throw new Error(marker);});
  try {
    console.error = (...args) => emitted.push(args.join(' '));
    const res = await fetch(`${t.url}/v1/merchant/contacts`, {
      headers: {authorization: 'Bearer synthetic'},
    });
    assert.equal(res.status, 500);
    const body = await res.text();
    assert.doesNotMatch(body, /777123456|1234|phone-/);
    assert.ok(emitted.some(s => s.includes('incident_id')));
    assert.doesNotMatch(emitted.join('\n'), /777123456|1234|phone-/);
  } finally {
    console.error = original;
    await t.close();
  }
});

test('unexpected malformed API URL returns controlled errors', async () => {
  const t = await serve(() => ({id: 'safe-test', role: 'merchant'}));
  try {
    const res = await fetch(`${t.url}/not-a-route`);
    assert.equal(res.status, 404);
    assert.equal((await res.json()).error, 'not_found');
  } finally {
    await t.close();
  }
});
