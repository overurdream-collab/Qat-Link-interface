// Isolated FIN25 enrollment service. Use behind trusted HTTPS reverse proxy.
import http from 'node:http';
import { createHash, timingSafeEqual } from 'node:crypto';
import { Pool } from 'pg';
import { createChallenge, challengePayload, fingerprint, verifyRsa, canonicalRequest, validateSignedMetadata } from './gateway_device_crypto.mjs';
const {DATABASE_URL, FIN25_ADMIN_KEY, FIN25_PORT='8082'}=process.env;
if(!DATABASE_URL || !FIN25_ADMIN_KEY || FIN25_ADMIN_KEY.length<32) throw Error('DATABASE_URL and strong FIN25_ADMIN_KEY required');
const pool=new Pool({connectionString:DATABASE_URL});
const hash=x=>createHash('sha256').update(x).digest('hex');
const respond=(res,status,body)=>{res.writeHead(status,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify(body));};
function admin(req){const key=req.headers['x-fin25-admin-key'];if(typeof key!=='string'||Buffer.byteLength(key)!==Buffer.byteLength(FIN25_ADMIN_KEY)||!timingSafeEqual(Buffer.from(key),Buffer.from(FIN25_ADMIN_KEY)))throw Object.assign(Error('Unauthorized'),{status:401});}
const server=http.createServer(async(req,res)=>{
 let client;
 try{
  if(req.method!=='POST')return respond(res,405,{error:'Method not allowed'});
  const chunks=[];let length=0;
  for await(const c of req){length+=c.length;if(length>8192)throw Object.assign(Error('Too large'),{status:413});chunks.push(c);}
  const raw=Buffer.concat(chunks).toString('utf8');
  let body;try{body=JSON.parse(raw)}catch{throw Object.assign(Error('Invalid JSON'),{status:400});}
  if(!body||typeof body!=='object'||Array.isArray(body))throw Object.assign(Error('Invalid body'),{status:400});
  const path=new URL(req.url,'http://localhost').pathname;
  const id=body.deviceId;
  if(['/v1/gateway/enroll','/v1/gateway/approve','/v1/gateway/revoke'].includes(path))admin(req);
  if(path==='/v1/gateway/enroll'){
   if(typeof id!=='string'||!/^[0-9a-f-]{36}$/i.test(id)||typeof body.publicKeyPem!=='string')throw Object.assign(Error('Invalid device'),{status:400});
   const fp=fingerprint(body.publicKeyPem);
   const result=await pool.query("INSERT INTO fin25_gateway_devices(device_id,public_key_spki_pem,fingerprint_sha256) VALUES($1,$2,$3) ON CONFLICT DO NOTHING RETURNING device_id",[id,body.publicKeyPem,fp]);
   if(!result.rowCount)throw Object.assign(Error('Device already exists; revoke and re-enroll through administrator'),{status:409});
   await pool.query("INSERT INTO fin25_gateway_audit(device_id,action) VALUES($1,'enroll')",[id]);
   return respond(res,201,{deviceId:id,status:'pending',fingerprint:fp});
  }
  if(path==='/v1/gateway/challenge'){
   if(typeof id!=='string')throw Object.assign(Error('Invalid device'),{status:400});
   client=await pool.connect();await client.query('BEGIN');
   const d=await client.query('SELECT status FROM fin25_gateway_devices WHERE device_id=$1 FOR UPDATE',[id]);
   if(d.rowCount!==1||d.rows[0].status!=='pending')throw Object.assign(Error('Not pending'),{status:409});
   const challenge=createChallenge();
   await client.query("INSERT INTO fin25_gateway_challenges(device_id,challenge_hash,expires_at) VALUES($1,$2,now()+interval '2 minutes') ON CONFLICT(device_id) DO UPDATE SET challenge_hash=EXCLUDED.challenge_hash,expires_at=EXCLUDED.expires_at,consumed_at=NULL",[id,hash(challenge)]);
   await client.query('COMMIT');client.release();client=null;
   return respond(res,200,{challenge,expiresInSeconds:120,signingPayload:challengePayload(id,challenge)});
  }
  if(path==='/v1/gateway/prove'){
   if(typeof id!=='string'||typeof body.challenge!=='string'||typeof body.signature!=='string')throw Object.assign(Error('Invalid proof'),{status:400});
   client=await pool.connect();await client.query('BEGIN');
   const d=await client.query("SELECT d.status,d.public_key_spki_pem,c.challenge_hash,c.expires_at,c.consumed_at FROM fin25_gateway_devices d JOIN fin25_gateway_challenges c ON c.device_id=d.device_id WHERE d.device_id=$1 FOR UPDATE OF d,c",[id]);
   if(d.rowCount!==1||d.rows[0].status!=='pending'||d.rows[0].consumed_at||new Date(d.rows[0].expires_at)<=new Date()||hash(body.challenge)!==d.rows[0].challenge_hash||!verifyRsa(d.rows[0].public_key_spki_pem,challengePayload(id,body.challenge),body.signature))throw Object.assign(Error('Invalid or expired proof'),{status:401});
   await client.query('UPDATE fin25_gateway_challenges SET consumed_at=now() WHERE device_id=$1',[id]);
   await client.query("UPDATE fin25_gateway_devices SET status='proved',proved_at=now() WHERE device_id=$1",[id]);
   await client.query("INSERT INTO fin25_gateway_audit(device_id,action) VALUES($1,'prove')",[id]);
   await client.query('COMMIT');client.release();client=null;
   return respond(res,200,{proved:true,status:'proved',approved:false});
  }
  if(path==='/v1/gateway/approve'||path==='/v1/gateway/revoke'){
   const action=path.endsWith('approve')?'approve':'revoke';
   client=await pool.connect();await client.query('BEGIN');
   const d=await client.query('SELECT status FROM fin25_gateway_devices WHERE device_id=$1 FOR UPDATE',[id]);
   if(d.rowCount!==1||(action==='approve'&&d.rows[0].status!=='proved'))throw Object.assign(Error('Device not proved'),{status:409});
   if(action==='approve')await client.query("UPDATE fin25_gateway_devices SET status='active',activated_at=now() WHERE device_id=$1",[id]);
   else await client.query("UPDATE fin25_gateway_devices SET status='revoked' WHERE device_id=$1",[id]);
   await client.query('INSERT INTO fin25_gateway_audit(device_id,action) VALUES($1,$2)',[id,action]);
   await client.query('COMMIT');client.release();client=null;
   return respond(res,200,{deviceId:id,status:action==='approve'?'active':'revoked'});
  }
  if(path==='/v1/gateway/heartbeat'){
   const deviceId=req.headers['x-device-id'],timestamp=req.headers['x-timestamp'],nonce=req.headers['x-nonce'],signature=req.headers['x-signature'];
   validateSignedMetadata({timestamp,nonce});
   client=await pool.connect();await client.query('BEGIN');
   const d=await client.query("SELECT public_key_spki_pem,status FROM fin25_gateway_devices WHERE device_id=$1 FOR UPDATE",[deviceId]);
   if(d.rowCount!==1||d.rows[0].status!=='active'||!verifyRsa(d.rows[0].public_key_spki_pem,canonicalRequest('POST',path,timestamp,nonce,raw),signature))throw Object.assign(Error('Unauthorized'),{status:401});
   const n=await client.query('INSERT INTO fin25_gateway_nonces(device_id,nonce_hash) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING device_id',[deviceId,hash(nonce)]);
   if(!n.rowCount)throw Object.assign(Error('Replay'),{status:401});
   await client.query('UPDATE fin25_gateway_devices SET last_seen_at=now() WHERE device_id=$1',[deviceId]);
   await client.query('COMMIT');client.release();client=null;
   return respond(res,200,{ok:true,status:'active'});
  }
  return respond(res,404,{error:'Not found'});
 }catch(e){if(client){await client.query('ROLLBACK').catch(()=>{});client.release();}return respond(res,e.status||500,{error:e.status?e.message:'Internal server error'});}
});
server.listen(Number(FIN25_PORT),'127.0.0.1',()=>console.info('FIN25 enrollment on loopback'));
