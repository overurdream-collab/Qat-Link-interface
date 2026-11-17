import assert from 'node:assert/strict';
import { randomUUID, generateKeyPairSync } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { Pool } from 'pg';

const pool = new Pool({connectionString:process.env.DATABASE_URL});
const device = randomUUID(), challenge = randomUUID(), job = randomUUID();
const {publicKey} = generateKeyPairSync('rsa',{modulusLength:3072});
const pem = publicKey.export({type:'spki',format:'pem'});
try {
  for(const filename of ['009_fin25_gateway_isolated.sql','010_fin25_otp_isolated.sql']){
    const sql=await readFile(new URL('../sql/'+filename,import.meta.url),'utf8');
    await pool.query(sql);
  }
  await pool.query('BEGIN');
  try {
    await pool.query('INSERT INTO fin25_gateway_devices(device_id,public_key_spki_pem,fingerprint_sha256) VALUES($1,$2,$3)',
      [device,pem,'a'.repeat(64)]);
    await pool.query("INSERT INTO fin25_otp_challenges(id,phone,code_digest,expires_at,resend_after) VALUES($1,$2,$3,now()+interval '5 minutes',now())",
      [challenge,'+967777000001','b'.repeat(64)]);
    await pool.query('INSERT INTO fin25_sms_jobs(id,challenge_id,recipient,encrypted_body) VALUES($1,$2,$3,$4)',
      [job,challenge,'+967777000001','synthetic encrypted placeholder']);
    const bad = await pool.query("SELECT count(*)::int AS n FROM fin25_gateway_devices WHERE device_id=$1 AND status='active'",[device]);
    assert.equal(bad.rows[0].n,0,'pending device must not be active');
    const nonce = await pool.query("INSERT INTO fin25_gateway_nonces(device_id,nonce_hash) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING device_id",[device,'c'.repeat(64)]);
    const replay = await pool.query("INSERT INTO fin25_gateway_nonces(device_id,nonce_hash) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING device_id",[device,'c'.repeat(64)]);
    assert.equal(nonce.rowCount,1);
    assert.equal(replay.rowCount,0,'replay nonce must be rejected');
    const pending = await pool.query("SELECT count(*)::int AS n FROM fin25_sms_jobs WHERE status='pending'");
    assert.equal(pending.rows[0].n,1);
    console.log('FIN25 PostgreSQL isolated schema, pending device, OTP queue and nonce replay: PASS');
  } finally { await pool.query('ROLLBACK'); }
} finally { await pool.end(); }
