import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createDecipheriv, createSign, generateKeyPairSync, randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import pg from 'pg';

const dbUrl = process.env.FIN25_TEST_DATABASE_URL;
if (!dbUrl) {
  test('FIN25 OTP HTTP end-to-end', {skip:'Isolated FIN25_TEST_DATABASE_URL not configured'},()=>{});
} else {
  const pool = new pg.Pool({connectionString:dbUrl});
  const key = randomBytes(32), hmacSecret = randomBytes(32).toString('hex'), internalKey = randomBytes(32).toString('hex');
  const {publicKey, privateKey} = generateKeyPairSync('rsa',{modulusLength:2048});
  const issuer='fin25-e2e-issuer', audience='fin25-e2e-audience';
  const port=18983, base='http://127.0.0.1:'+port;
  let child;
  const phone='+967700000009';
  const post=async(path,body,headers={})=>{
    const res=await fetch(base+path,{method:'POST',headers:{'content-type':'application/json',...headers},body:JSON.stringify(body)});
    return {status:res.status,body:await res.json()};
  };
  function token(role='identity_service') {
    const now=Math.floor(Date.now()/1000);
    const a=Buffer.from(JSON.stringify({alg:'RS256',typ:'JWT'})).toString('base64url');
    const b=Buffer.from(JSON.stringify({iss:issuer,aud:audience,sub:'synthetic-identity',role,iat:now-1,exp:now+120})).toString('base64url');
    const s=createSign('RSA-SHA256');s.update(a+'.'+b);s.end();
    return 'Bearer '+a+'.'+b+'.'+s.sign(privateKey).toString('base64url');
  }
  test.before(async()=>{
    for(const file of ['009_fin25_gateway_isolated.sql','010_fin25_otp_isolated.sql']){
      const sql=await readFile(new URL('../sql/'+file,import.meta.url),'utf8');
      await pool.query(sql);
    }
    child=spawn(process.execPath,['src/fin25_otp_transport.mjs'],{
      cwd:new URL('..',import.meta.url).pathname,
      env:{...process.env,DATABASE_URL:dbUrl,OTP_HMAC_SECRET:hmacSecret,OTP_ENCRYPTION_KEY_HEX:key.toString('hex'),OTP_INTERNAL_API_KEY:internalKey,JWT_PUBLIC_KEY_PEM:publicKey.export({format:'pem',type:'spki'}),JWT_ISSUER:issuer,JWT_AUDIENCE:audience,OTP_ENABLED:'true',FIN25_SMS_DISPATCH_ENABLED:'false',FIN25_OTP_PORT:String(port),FIN25_BIND_HOST:'127.0.0.1'},
      stdio:'ignore'
    });
    let ready=false;
    for(let i=0;i<70;i++){
      if(child.exitCode!==null)break;
      try {const r=await post('/not-found',{});if(r.status===404){ready=true;break;}}catch{}
      await new Promise(r=>setTimeout(r,100));
    }
    assert.equal(ready,true,'FIN25 HTTP service did not start');
  });
  test.after(async()=>{
    if(child){child.kill('SIGTERM');}
    await pool.query('DELETE FROM fin25_sms_jobs WHERE recipient=$1',[phone]);
    await pool.query('DELETE FROM fin25_otp_challenges WHERE phone=$1',[phone]);
    await pool.end();
  });
  test('OTP HTTP request -> synthetic sent -> verify -> one-time identity proof',async()=>{
    const requested=await post('/v1/auth/otp/request',{phone});
    assert.equal(requested.status,202);
    const id=requested.body.requestId;
    assert.match(id,/^[a-f0-9-]{36}$/i);
    const job=await pool.query('SELECT id,encrypted_body,status FROM fin25_sms_jobs WHERE challenge_id=$1',[id]);
    assert.equal(job.rowCount,1);
    assert.equal(job.rows[0].status,'pending');
    const encrypted=Buffer.from(job.rows[0].encrypted_body,'base64');
    const decipher=createDecipheriv('aes-256-gcm',key,encrypted.subarray(0,12));
    decipher.setAuthTag(encrypted.subarray(12,28));
    const sms=Buffer.concat([decipher.update(encrypted.subarray(28)),decipher.final()]).toString('utf8');
    const code=sms.match(/\b\d{6}\b/)?.[0];
    assert.match(code,/^\d{6}$/);
    assert.equal((await post('/v1/auth/otp/verify',{requestId:id,code})).status,401,'unsent OTP cannot verify');
    await pool.query("UPDATE fin25_sms_jobs SET status='sent' WHERE id=$1",[job.rows[0].id]);
    const verified=await post('/v1/auth/otp/verify',{requestId:id,code});
    assert.equal(verified.status,200);
    assert.equal(verified.body.verified,true);
    assert.equal((await post('/v1/auth/otp/verify',{requestId:id,code})).status,401,'consumed OTP cannot be reused');
    const headers={authorization:token(),'x-internal-api-key':internalKey};
    assert.equal((await post('/v1/internal/otp/proof',{proofToken:verified.body.proofToken},{'x-internal-api-key':internalKey})).status,401,'JWT required');
    assert.equal((await post('/v1/internal/otp/proof',{proofToken:verified.body.proofToken},{authorization:token('merchant'),'x-internal-api-key':internalKey})).status,403,'merchant forbidden');
    const proof=await post('/v1/internal/otp/proof',{proofToken:verified.body.proofToken},headers);
    assert.equal(proof.status,200);
    assert.equal(proof.body.phone,phone);
    assert.equal((await post('/v1/internal/otp/proof',{proofToken:verified.body.proofToken},headers)).status,401,'proof is single-use');
  });
  test('OTP HTTP requires only +967 and exactly 9 ASCII digits',async()=>{
    for(const invalid of ['+966551234567','+96712345678','+9671234567890',
      '+967٧٧٦٦٤٤٣١٢','+968123456789']) {
      const result=await post('/v1/auth/otp/request',{phone:invalid});
      assert.equal(result.status,400,invalid);
    }
    const sabafon72='+967751234567';
    const result=await post('/v1/auth/otp/request',{phone:sabafon72});
    assert.equal(result.status,202);
    await pool.query('DELETE FROM fin25_sms_jobs WHERE recipient=$1',[sabafon72]);
    await pool.query('DELETE FROM fin25_otp_challenges WHERE phone=$1',[sabafon72]);
  });

  test('OTP HTTP throttles immediate duplicate requests',async()=>{
    const result=await post('/v1/auth/otp/request',{phone});
    assert.equal(result.status,429);
  });
}
