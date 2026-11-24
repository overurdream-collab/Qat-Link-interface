import test from 'node:test';
import assert from 'node:assert/strict';
import { databaseTls, boundHttpServer } from '../src/service_security.mjs';

test('Identity and FIN25 production DB connections require verified TLS', () => {
  for (const flag of ['PG_SSL','IDENTITY_PG_SSL']) {
    for (const value of [undefined,'false','0']) {
      assert.throws(() => databaseTls({NODE_ENV:'production',[flag]:value},flag), /Production requires/);
    }
    assert.deepEqual(databaseTls({NODE_ENV:'production',[flag]:'true'},flag),{rejectUnauthorized:true});
  }
  assert.equal(databaseTls({NODE_ENV:'test'}),undefined);
});

test('Identity and FIN25 servers bound slow and idle connections', () => {
  const server = boundHttpServer({});
  assert.equal(server.headersTimeout,10000);
  assert.equal(server.requestTimeout,15000);
  assert.equal(server.keepAliveTimeout,5000);
  assert.equal(server.maxRequestsPerSocket,100);
});
