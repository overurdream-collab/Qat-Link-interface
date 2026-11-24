import test from 'node:test';
import assert from 'node:assert/strict';
import { createIdentityFinanceWriteProxy } from '../src/identity_fin08_write_proxy.mjs';

const session = 'Bearer test-token-not-a-real-jwt';
const merchant = { id: 'merchant-1', role: 'merchant' };
const customer = { id: 'customer-1', role: 'customer' };
const relationship = '11111111-1111-4111-8111-111111111111';
const operation = '22222222-2222-4222-8222-222222222222';

function proxyWith(fetchImpl) {
  return createIdentityFinanceWriteProxy({
    financeBaseUrl: 'http://fin08-private:8080/', fetchImpl,
  });
}

test('write proxy allows merchant contact creation and forwards safe headers', async () => {
  const calls = [];
  const proxy = proxyWith(async (url, options) => {
    calls.push({ url: url.toString(), options });
    return new Response(JSON.stringify({ id: 'contact-1' }), {
      status: 201, headers: { 'content-type': 'application/json' },
    });
  });
  const body = JSON.stringify({ name: 'متجر', phone: '+967771234567' });
  const result = await proxy({
    url: '/v1/merchant/contacts', authorization: session, account: merchant,
    body, idempotencyKey: 'req-1',
  });
  assert.deepEqual(result, { status: 201, data: { id: 'contact-1' } });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://fin08-private:8080/v1/merchant/contacts');
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.headers.authorization, session);
  assert.equal(calls[0].options.headers['idempotency-key'], 'req-1');
  assert.equal(calls[0].options.body, body);
});

test('write proxy permits relationship mutations for both participant roles and preserves conflicts', async () => {
  const seen = [];
  const proxy = proxyWith(async (url) => {
    seen.push(url.pathname);
    return new Response(JSON.stringify({ error: 'conflict', secret: 'db_secret' }), {
      status: 409, headers: { 'content-type': 'application/json' },
    });
  });
  for (const account of [merchant, customer]) {
    const result = await proxy({
      url: `/v1/relationships/${relationship}/operations`,
      authorization: session, account, body: '{"type":"debt","amount":"1"}',
    });
    assert.equal(result.status, 409);
    assert.equal(result.data.error, 'conflict');
    assert.equal(result.data.secret, undefined);
  }
  await proxy({
    url: `/v1/relationships/${relationship}/operations/${operation}/decision`,
    authorization: session, account: customer, body: '{"decision":"accept"}',
  });
  assert.deepEqual(seen, [
    `/v1/relationships/${relationship}/operations`,
    `/v1/relationships/${relationship}/operations`,
    `/v1/relationships/${relationship}/operations/${operation}/decision`,
  ]);
});

test('write proxy denies unlisted routes, wrong roles, queries and unsafe idempotency keys', async () => {
  let calls = 0;
  const proxy = proxyWith(async () => { calls++; throw new Error('must never run'); });
  for (const args of [
    { url: '/v1/merchant/contacts?merchant_id=other', account: merchant },
    { url: '/v1/merchant/contacts', account: customer },
    { url: `/v1/customer/relationships/${relationship}/decision`, account: merchant },
    { url: `/v1/merchant/amendments/${relationship}/decision`, account: customer },
    { url: '/v1/internal/merchant-profiles', account: merchant },
    { url: '/v1/relationships/../../internal/x/operations', account: merchant },
    { url: '/v1/merchant/contacts', account: merchant, idempotencyKey: 'bad key!' },
  ]) {
    await assert.rejects(proxy({ ...args, authorization: session, body: '{}' }));
  }
  assert.equal(calls, 0);
});

test('write proxy rejects missing auth or body and hides upstream failures', async () => {
  const proxy = proxyWith(async () => new Response(JSON.stringify({ error: 'db_secret' }), {
    status: 500, headers: { 'content-type': 'application/json' },
  }));
  await assert.rejects(proxy({
    url: '/v1/merchant/contacts', account: merchant, body: '{}',
  }), e => e.status === 401);
  await assert.rejects(proxy({
    url: '/v1/merchant/contacts', authorization: session, account: merchant,
  }), e => e.status === 400);
  await assert.rejects(proxy({
    url: '/v1/merchant/contacts', authorization: session, account: merchant, body: '[]',
  }), e => e.status === 400);
  await assert.rejects(proxy({
    url: '/v1/merchant/contacts', authorization: session, account: merchant, body: '{}',
  }), e => e.status === 503 && !e.message.includes('db_secret'));
});
