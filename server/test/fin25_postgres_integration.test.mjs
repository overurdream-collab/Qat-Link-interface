import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import pg from 'pg';

const url = process.env.FIN25_TEST_DATABASE_URL;
if (!url) throw new Error('FIN25_TEST_DATABASE_URL required: isolated test database only');
const pool = new pg.Pool({ connectionString: url, max: 8 });
const prefix = 'fin25_it_' + randomUUID().replaceAll('-', '');
const deviceId = randomUUID();
const challengeId = randomUUID();
const jobId = randomUUID();
const nonceHash = n => createHash('sha256').update(n).digest('hex');
const run = (q, values) => pool.query(q.replaceAll('fin25_', prefix + '_'), values);

test.before(async () => {
  const sqls = ['009_fin25_gateway_isolated.sql', '010_fin25_otp_isolated.sql'];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(251025)');
    for (const file of sqls) {
      const sql = (await readFile(new URL('../sql/' + file, import.meta.url), 'utf8'))
        .replace(/^BEGIN;|^COMMIT;/gm, '')
        .replaceAll('fin25_', prefix + '_');
      await client.query(sql);
    }
    await client.query('COMMIT');
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
  await run('INSERT INTO fin25_gateway_devices(device_id,public_key_spki_pem,fingerprint_sha256,status) VALUES($1,$2,$3,$4)',
    [deviceId, 'synthetic-key', 'a'.repeat(64), 'active']);
  await run("INSERT INTO fin25_otp_challenges(id,phone,code_digest,expires_at,resend_after) VALUES($1,$2,$3,now()+interval '5 minutes',now()+interval '1 minute')",
    [challengeId, '+967700000001', 'b'.repeat(64)]);
  await run('INSERT INTO fin25_sms_jobs(id,challenge_id,recipient,encrypted_body) VALUES($1,$2,$3,$4)',
    [jobId, challengeId, '+967700000001', 'synthetic-encrypted-placeholder']);
});
test.after(async () => {
  try {
    for (const table of ['sms_jobs','otp_challenges','gateway_audit','gateway_nonces','gateway_challenges','gateway_devices']) {
      await pool.query('DROP TABLE IF EXISTS ' + prefix + '_' + table + ' CASCADE');
    }
  } finally { await pool.end(); }
});
test('database enforces nonce uniqueness even under concurrent inserts', async () => {
  const nonce = nonceHash('synthetic-replay');
  const results = await Promise.all(Array.from({length: 12}, () =>
    run('INSERT INTO fin25_gateway_nonces(device_id,nonce_hash) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING device_id', [deviceId, nonce])));
  assert.equal(results.reduce((n, r) => n + r.rowCount, 0), 1);
});
test('same nonce hash is isolated per approved device', async () => {
  const other = randomUUID();
  await run('INSERT INTO fin25_gateway_devices(device_id,public_key_spki_pem,fingerprint_sha256,status) VALUES($1,$2,$3,$4)',
    [other, 'synthetic-key-2', 'c'.repeat(64), 'active']);
  const nonce = nonceHash('synthetic-replay');
  const result = await run('INSERT INTO fin25_gateway_nonces(device_id,nonce_hash) VALUES($1,$2) RETURNING device_id', [other, nonce]);
  assert.equal(result.rowCount, 1);
});
test('OTP proof digest is unique and one-time redemption is atomic', async () => {
  const proof = 'd'.repeat(64);
  await run("UPDATE fin25_otp_challenges SET proof_digest=$2,proof_expires_at=now()+interval '2 minutes' WHERE id=$1", [challengeId,proof]);
  const results = await Promise.all(Array.from({length: 10}, () =>
    run("UPDATE fin25_otp_challenges SET proof_redeemed_at=now() WHERE proof_digest=$1 AND proof_expires_at>now() AND proof_redeemed_at IS NULL RETURNING phone", [proof])));
  assert.equal(results.reduce((n,r)=>n+r.rowCount,0),1);
});
test('OTP challenges cannot exceed five verification attempts', async () => {
  await assert.rejects(run('UPDATE fin25_otp_challenges SET attempts=6 WHERE id=$1',[challengeId]), e => e.code === '23514');
});
test('SMS queue enforces one job per challenge and valid status', async () => {
  await assert.rejects(run('INSERT INTO fin25_sms_jobs(id,challenge_id,recipient,encrypted_body) VALUES($1,$2,$3,$4)',
    [randomUUID(),challengeId,'+967700000001','placeholder']), e=>e.code==='23505');
  await assert.rejects(run("UPDATE fin25_sms_jobs SET status='unknown' WHERE id=$1",[jobId]),e=>e.code==='23514');
});
test('SMS jobs cannot reference a nonexistent challenge', async () => {
  await assert.rejects(run('INSERT INTO fin25_sms_jobs(id,challenge_id,recipient,encrypted_body) VALUES($1,$2,$3,$4)',
    [randomUUID(),randomUUID(),'+967700000001','placeholder']),e=>e.code==='23503');
});
