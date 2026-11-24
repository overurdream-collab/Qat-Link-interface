import test from 'node:test';
import assert from 'node:assert/strict';
import { Client } from 'pg';
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


test('PostgreSQL URL parameters cannot override verified TLS in any service', () => {
  const base = 'postgres://synthetic:never-log-this-secret@127.0.0.1/test';
  for (const flag of ['PG_SSL','IDENTITY_PG_SSL']) {
    const urlName = flag === 'IDENTITY_PG_SSL' ? 'IDENTITY_DATABASE_URL' : 'DATABASE_URL';
    for (const query of ['sslmode=disable','sslmode=no-verify','ssl=0','ssl=no-verify',
      'sslcert=/sensitive','sslkey=/sensitive','sslrootcert=/sensitive',
      'uselibpqcompat=true','%73slmode=disable','SSLMode=disable']) {
      const env = {NODE_ENV:'production',[flag]:'true',[urlName]:base+'?'+query};
      assert.throws(() => databaseTls(env,flag), error =>
        /TLS overrides are forbidden/.test(error.message) &&
        !/never-log|sensitive|postgres:/.test(error.message));
    }
    const connectionString = base+'?application_name=synthetic-ci';
    const env = {NODE_ENV:'production',[flag]:'true',[urlName]:connectionString};
    const client = new Client({connectionString,ssl:databaseTls(env,flag)});
    assert.deepEqual(client.connectionParameters.ssl,{rejectUnauthorized:true},
      'inspect effective pg configuration after URL parsing without making a connection');
  }
});
