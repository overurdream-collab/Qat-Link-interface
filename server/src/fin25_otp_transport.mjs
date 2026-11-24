// Standalone OTP transport API for Maqwati Link and Android Gateway.
// Run behind HTTPS reverse proxy. JWT identity issuance is intentionally separate.
import http from 'node:http';
import { randomInt, randomUUID, createHmac, timingSafeEqual, createDecipheriv, createCipheriv, createVerify } from 'node:crypto';
import { Pool } from 'pg';
import { verifyRsa, canonicalRequest, validateSignedMetadata } from './gateway_device_crypto.mjs';
import { createHash } from 'node:crypto';
import { createVerifier } from './auth.mjs';

const env = process.env;
for (const k of ['DATABASE_URL','OTP_HMAC_SECRET','OTP_ENCRYPTION_KEY_HEX','OTP_INTERNAL_API_KEY'])
  if (!env[k]) throw new Error('Missing '+k);
const key = Buffer.from(env.OTP_ENCRYPTION_KEY_HEX,'hex');
if (key.length !== 32) throw new Error('OTP_ENCRYPTION_KEY_HEX must be 32-byte hex');
const pool = new Pool({connectionString:env.DATABASE_URL});
const identityVerifier = createVerifier({
 publicKey: env.JWT_PUBLIC_KEY_PEM?.replace(/\\n/g,'\n'),
 issuer: env.JWT_ISSUER, audience: env.JWT_AUDIENCE,
});
const digest=(id,code)=>createHmac('sha256',env.OTP_HMAC_SECRET).update(id+':'+code).digest('hex');
function encrypt(s) {
 const iv=cryptoRandom(12),c=createCipheriv('aes-256-gcm',key,iv);
 const payload=Buffer.concat([c.update(s,'utf8'),c.final()]);
 return Buffer.concat([iv,c.getAuthTag(),payload]).toString('base64');
}
function decrypt(s) {
 const b=Buffer.from(s,'base64'),d=createDecipheriv('aes-256-gcm',key,b.subarray(0,12));
 d.setAuthTag(b.subarray(12,28));
 return Buffer.concat([d.update(b.subarray(28)),d.final()]).toString('utf8');
}
import { randomBytes as cryptoRandom } from 'node:crypto';
function reply(res,status,obj) {res.writeHead(status,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify(obj));}
function assert(ok,status,message){if(!ok)throw Object.assign(new Error(message),{status});}
async function json(req) {
 const chunks=[];let length=0;
 for await(const chunk of req){length+=chunk.length;assert(length<=8192,413,'Payload too large');chunks.push(chunk);}
 const raw=Buffer.concat(chunks).toString('utf8');
 let data;try{data=JSON.parse(raw||'{}')}catch{assert(false,400,'Invalid JSON')}
 assert(data&&typeof data==='object'&&!Array.isArray(data),400,'Invalid JSON');
 return {data,raw};
}
function phone(v){assert(typeof v==='string'&&/^\+967[0-9]{9}$/.test(v),400,'Use +967 followed by 9 digits');return v;}
function internal(req){
 const actor=identityVerifier(req.headers.authorization);
 assert(actor.role==='identity_service',403,'Identity service only');
 const x=req.headers['x-internal-api-key'];
 assert(typeof x==='string'&&x.length===env.OTP_INTERNAL_API_KEY.length&&timingSafeEqual(Buffer.from(x),Buffer.from(env.OTP_INTERNAL_API_KEY)),401,'Unauthorized');
}
async function signed(req,raw){
 const id=req.headers['x-device-id'],stamp=req.headers['x-timestamp'],nonce=req.headers['x-nonce'],sig=req.headers['x-signature'];
 assert([id,stamp,nonce,sig].every(x=>typeof x==='string'),401,'Missing device signature');
 try { validateSignedMetadata({timestamp:stamp,nonce}); } catch { assert(false,401,'Invalid signature metadata'); }
 const d=await pool.query("SELECT public_key_spki_pem FROM fin25_gateway_devices WHERE device_id=$1 AND status='active'",[id]);
 assert(d.rowCount===1,401,'Device not approved');
 const path=new URL(req.url,'http://localhost').pathname;
 assert(verifyRsa(d.rows[0].public_key_spki_pem,canonicalRequest(req.method,path,stamp,nonce,raw),sig),401,'Invalid signature');
 const nonceHash=createHash('sha256').update(nonce).digest('hex');
 const n=await pool.query('INSERT INTO fin25_gateway_nonces(device_id,nonce_hash) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING device_id',[id,nonceHash]);
 assert(n.rowCount===1,401,'Replay');
 return id;
}
const api=http.createServer(async(req,res)=>{
 let client;
 try {
  const {data,raw}=await json(req);
  const path=new URL(req.url,'http://localhost').pathname;
  if(req.method!=='POST')return reply(res,405,{error:'Method not allowed'});
  if(path==='/v1/auth/otp/request'||path==='/v1/auth/otp/public-request'){
   const isPublic=path==='/v1/auth/otp/public-request';
   // Operator's local endpoint remains separate. Public sends are disabled by
   // default and have a PostgreSQL-serialized hourly global SMS budget.
   if(isPublic){
    assert(env.OTP_PUBLIC_REQUEST_ENABLED==='true',503,'Public OTP disabled');
    const max=Number(env.OTP_PUBLIC_MAX_PER_HOUR);
    assert(Number.isInteger(max)&&max>=1&&max<=120,503,'Public OTP budget not configured');
   }
   assert(env.OTP_ENABLED==='true',503,'OTP disabled');
   const p=phone(data.phone),id=randomUUID(),code=String(randomInt(0,1000000)).padStart(6,'0');
   client=await pool.connect();await client.query('BEGIN');
   if(isPublic){
    // Lock independent of the per-phone lock: multiple phones cannot bypass
    // the global budget concurrently. Phone/OTP details are never logged.
    await client.query('SELECT pg_advisory_xact_lock($1)',[2026112101]);
    const count=await client.query("SELECT count(*)::int AS n FROM fin25_otp_challenges WHERE created_at>now()-interval '1 hour'");
    assert(count.rows[0].n<Number(env.OTP_PUBLIC_MAX_PER_HOUR),429,'SMS budget exhausted');
   }
   await client.query('SELECT pg_advisory_xact_lock(hashtext($1))',[p]);
   const recent=await client.query("SELECT count(*)::int AS n,max(created_at) AS last FROM fin25_otp_challenges WHERE phone=$1 AND created_at>now()-interval '1 hour'",[p]);
   assert(recent.rows[0].n<5,429,'Too many requests');
   const last=recent.rows[0].last;
   assert(!last||Date.now()-new Date(last).getTime()>=60000,429,'Wait before resending');
   await client.query("INSERT INTO fin25_otp_challenges(id,phone,code_digest,expires_at,resend_after) VALUES($1,$2,$3,now()+interval '5 minutes',now()+interval '60 seconds')",[id,p,digest(id,code)]);
   await client.query('INSERT INTO fin25_sms_jobs(id,challenge_id,recipient,encrypted_body) VALUES($1,$2,$3,$4)',[randomUUID(),id,p,encrypt('Your Maqwati Link verification code: '+code)]);
   await client.query('COMMIT');client.release();client=null;
   return reply(res,202,{requestId:id,expiresInSeconds:300,retryAfterSeconds:60});
  }
  if(path==='/v1/auth/otp/verify'){
   const {requestId,code}=data;
   assert(typeof requestId==='string'&&/^[0-9a-f-]{36}$/i.test(requestId)&&typeof code==='string'&&/^\d{6}$/.test(code),400,'Invalid request');
   client=await pool.connect();await client.query('BEGIN');
   const x=await client.query('SELECT * FROM fin25_otp_challenges WHERE id=$1 FOR UPDATE',[requestId]);
   assert(x.rowCount===1,401,'Invalid or expired code');
   const ch=x.rows[0];
   const sent=await client.query("SELECT 1 FROM fin25_sms_jobs WHERE challenge_id=$1 AND status IN ('sent','delivered')",[requestId]);
   assert(sent.rowCount===1,401,'OTP not confirmed sent');
   assert(!ch.consumed_at&&new Date(ch.expires_at)>new Date()&&ch.attempts<5,401,'Invalid or expired code');
   await client.query('UPDATE fin25_otp_challenges SET attempts=attempts+1 WHERE id=$1',[requestId]);
   const a=Buffer.from(ch.code_digest,'hex'),b=Buffer.from(digest(requestId,code),'hex');
   if(!timingSafeEqual(a,b)) { await client.query('COMMIT');client.release();client=null; return reply(res,401,{error:'Invalid or expired code'}); }
   const proof=randomUUID()+randomUUID();
   const proofHash=createHmac('sha256',env.OTP_HMAC_SECRET).update('proof:'+proof).digest('hex');
   await client.query("UPDATE fin25_otp_challenges SET consumed_at=now(),proof_digest=$2,proof_expires_at=now()+interval '2 minutes' WHERE id=$1",[requestId,proofHash]);
   await client.query('COMMIT');client.release();client=null;
   // Proof is returned only to trusted identity backend; NEVER issue a role or JWT based on phone alone.
   return reply(res,200,{verified:true,proofToken:proof,expiresInSeconds:120});
  }
  if(path==='/v1/gateway/poll'){
   const device=await signed(req,raw);
   assert(env.FIN25_SMS_DISPATCH_ENABLED==='true',503,'SMS dispatch disabled by operator');
   client=await pool.connect();await client.query('BEGIN');
   const x=await client.query("SELECT j.id,j.recipient,j.encrypted_body FROM fin25_sms_jobs j JOIN fin25_otp_challenges c ON c.id=j.challenge_id WHERE j.status='pending' AND c.expires_at>now() AND j.attempts<3 ORDER BY j.created_at FOR UPDATE OF j SKIP LOCKED LIMIT 1");
   if(!x.rowCount){await client.query('COMMIT');client.release();client=null;return reply(res,200,{job:null});}
   const j=x.rows[0];
   await client.query("UPDATE fin25_sms_jobs SET status='leased',device_id=$2,lease_until=now()+interval '45 seconds',attempts=attempts+1 WHERE id=$1",[j.id,device]);
   await client.query('COMMIT');client.release();client=null;
   return reply(res,200,{job:{id:j.id,recipient:j.recipient,text:decrypt(j.encrypted_body)}});
  }
  // Expired leases are not requeued automatically: uncertain SMS requires reconciliation.
  if(path==='/v1/gateway/result'){
   const device=await signed(req,raw);
   assert(typeof data.jobId==='string'&&['sent','failed','delivered'].includes(data.status),400,'Invalid result');
   assert(Number.isInteger(data.simSlot)&&data.simSlot>=0,400,'Invalid SIM slot');
   client=await pool.connect();await client.query('BEGIN');
   const current=await client.query('SELECT status,device_id FROM fin25_sms_jobs WHERE id=$1 FOR UPDATE',[data.jobId]);
   assert(current.rowCount===1&&current.rows[0].device_id===device,409,'Job not leased to device');
   const previous=current.rows[0].status;
   // Repeated ACKs are idempotent; never downgrade sent/delivered to failed.
   if(previous===data.status){await client.query('COMMIT');client.release();client=null;return reply(res,200,{accepted:true,duplicate:true});}
   assert((previous==='leased'&&['sent','failed'].includes(data.status))||
     (previous==='sent'&&data.status==='delivered'),409,'Invalid job state transition');
   await client.query("UPDATE fin25_sms_jobs SET status=$2,sim_slot=$3,sent_at=CASE WHEN $2='sent' THEN now() ELSE sent_at END,lease_until=NULL WHERE id=$1",
     [data.jobId,data.status,data.simSlot]);
   await client.query('COMMIT');client.release();client=null;
   return reply(res,200,{accepted:true});
  }
  if(path==='/v1/gateway/heartbeat'){
   const device=await signed(req,raw);
   await pool.query('UPDATE fin25_gateway_devices SET last_seen_at=now() WHERE device_id=$1',[device]);
   return reply(res,200,{ok:true});
  }
  if(path==='/v1/internal/otp/proof'){
   internal(req);
   // Reserved for server-to-server proof exchange. Never expose a phone from an unauthenticated caller.
   assert(typeof data.proofToken==='string'&&data.proofToken.length===72,400,'Invalid proof');
   const hash=createHmac('sha256',env.OTP_HMAC_SECRET).update('proof:'+data.proofToken).digest('hex');
   client=await pool.connect();await client.query('BEGIN');
   const proof=await client.query("UPDATE fin25_otp_challenges SET proof_redeemed_at=now() WHERE proof_digest=$1 AND proof_expires_at>now() AND proof_redeemed_at IS NULL RETURNING phone",[hash]);
   await client.query('COMMIT');client.release();client=null;
   assert(proof.rowCount===1,401,'Invalid or expired proof');
   return reply(res,200,{verified:true,phone:proof.rows[0].phone});
  }
  return reply(res,404,{error:'Not found'});
 }catch(e){if(client){try{await client.query('ROLLBACK')}catch{}client.release()}
  return reply(res,e.status||500,{error:e.status?e.message:'Internal server error'});
 }
});
api.listen(Number(env.FIN25_OTP_PORT||8083),env.FIN25_BIND_HOST||'127.0.0.1',()=>console.info('FIN25 OTP transport listening on loopback'));
