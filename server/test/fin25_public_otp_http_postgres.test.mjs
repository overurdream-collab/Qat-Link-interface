import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:net';
import { spawn } from 'node:child_process';
import { randomBytes, generateKeyPairSync } from 'node:crypto';
import { Pool } from 'pg';

// Isolated PostgreSQL only. Never runs against a live FIN25 test database.
const connectionString = process.env.IDENTITY_CI_DATABASE_URL;
const wait = ms => new Promise(r => setTimeout(r, ms));
async function freePort() {
  const s = createServer();
  await new Promise(r => s.listen(0, '127.0.0.1', r));
  const port=s.address().port;
  await new Promise(r => s.close(r));
  return port;
}
async function startServer(config) {
  const port=await freePort();
  const p=spawn(process.execPath,['src/fin25_otp_transport.mjs'],{
    cwd:new URL('../',import.meta.url),stdio:'ignore',
    env:{...process.env,...config,FIN25_OTP_PORT:String(port),FIN25_BIND_HOST:'127.0.0.1'}
  });
  const origin='http://127.0.0.1:'+port;
  for(let n=0;n<100;n++){
    if(p.exitCode!==null) throw new Error('FIN25 OTP service exited unexpectedly');
    try {
      const r=await fetch(origin+'/v1/auth/otp/public-request',{
        method:'POST',headers:{'content-type':'application/json'},body:'{}'
      });
      if(r.status) return {origin,p};
    } catch {}
    await wait(80);
  }
  p.kill('SIGTERM');
  throw new Error('FIN25 OTP service did not start');
}
async function stopServer(p) {
  if(!p||p.exitCode!==null) return;
  p.kill('SIGTERM');
  await new Promise(resolve=>{p.once('exit',resolve);setTimeout(resolve,1500).unref();});
}
async function post(origin,path,phone) {
  const r=await fetch(origin+path,{
    method:'POST',headers:{'content-type':'application/json'},
    body:JSON.stringify({phone})
  });
  return {status:r.status,body:await r.json()};
}
test('Public OTP: fail closed, 2-message SQL global budget, no retries or SMS gateway dispatch',
  {skip:!connectionString,timeout:30000},async()=>{
    const pool=new Pool({connectionString});
    const {publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
    const env={
      DATABASE_URL:connectionString,OTP_HMAC_SECRET:randomBytes(32).toString('hex'),
      OTP_ENCRYPTION_KEY_HEX:randomBytes(32).toString('hex'),
      OTP_INTERNAL_API_KEY:randomBytes(32).toString('hex'),
      JWT_PUBLIC_KEY_PEM:publicKey.export({type:'spki',format:'pem'}),
      JWT_ISSUER:'ci-only',JWT_AUDIENCE:'ci-only',
      OTP_ENABLED:'true',OTP_PUBLIC_REQUEST_ENABLED:'false',
      OTP_PUBLIC_MAX_PER_HOUR:'2',FIN25_SMS_DISPATCH_ENABLED:'false'
    };
    let service,blocked;
    try {
      blocked=await startServer(env);
      assert.equal((await post(blocked.origin,'/v1/auth/otp/public-request','+967700000001')).status,503);
      assert.equal((await post(blocked.origin,'/v1/auth/otp/request','+967700000001')).status,401,
        'direct operator endpoint must require service authentication even when OTP is enabled');
      const deniedQueue=await pool.query('SELECT count(*)::int AS n FROM fin25_sms_jobs');
      assert.equal(deniedQueue.rows[0].n,0,'unauthenticated request must not queue SMS');
      await stopServer(blocked.p);blocked=null;

      service=await startServer({...env,OTP_PUBLIC_REQUEST_ENABLED:'true'});
      for (const invalid of ['+966551234567','+967112345678','+967751234567','+967٧٧١٢٣٤٥٦٧']) {
        assert.equal((await post(service.origin,'/v1/auth/otp/public-request',invalid)).status,400,
          'unsupported/non-ASCII mobile recipient must be rejected');
      }
      const one=await post(service.origin,'/v1/auth/otp/public-request','+967700000001');
      const two=await post(service.origin,'/v1/auth/otp/public-request','+967720000002');
      const three=await post(service.origin,'/v1/auth/otp/public-request','+967700000003');
      assert.equal(one.status,202);assert.equal(two.status,202);
      assert.equal(three.status,429,'global budget must deny a third phone');
      assert.match(one.body.requestId,/^[0-9a-f-]{36}$/i);
      assert.ok(!('code' in one.body),'OTP code must not be returned');
      const record=await pool.query(
        "SELECT count(*)::int AS count FROM fin25_otp_challenges WHERE phone IN ('+967700000001','+967720000002')");
      assert.equal(record.rows[0].count,2);
      const pending=await pool.query(
        "SELECT count(*)::int AS count FROM fin25_sms_jobs WHERE status='pending'");
      assert.equal(pending.rows[0].count,2,'No real SMS or gateway delivery is performed in this test');
    }finally{
      await stopServer(service?.p);await stopServer(blocked?.p);
      await pool.end();
    }
  });
