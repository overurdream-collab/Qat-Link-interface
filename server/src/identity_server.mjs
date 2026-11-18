// P0 identity API is a separate process. It does NOT alter running FIN25 OTP/SMS.
import { createServer } from 'node:http';
import { Pool } from 'pg';
import { createIdentityLogic, IdentityError } from './identity_logic.mjs';

const env = process.env;
const required = [
  'IDENTITY_DATABASE_URL','IDENTITY_PRIVATE_KEY_PEM','IDENTITY_PUBLIC_KEY_PEM',
  'IDENTITY_ISSUER','IDENTITY_AUDIENCE','FIN25_INTERNAL_PROOF_URL','FIN25_INTERNAL_API_KEY'
];
for(const k of required) if(!env[k]) throw new Error('Missing identity configuration: '+k);
const port = Number(env.IDENTITY_PORT || 8090);
if(!Number.isInteger(port) || port<1 || port>65535) throw new Error('Invalid IDENTITY_PORT');
const pool = new Pool({connectionString:env.IDENTITY_DATABASE_URL,
  ssl:env.IDENTITY_PG_SSL==='true'?{rejectUnauthorized:true}:undefined,max:5});
const logic = createIdentityLogic({
  pool,fetchImpl:fetch,
  settings:{
    privateKey:env.IDENTITY_PRIVATE_KEY_PEM.replace(/\\n/g,'\n'),
    publicKey:env.IDENTITY_PUBLIC_KEY_PEM.replace(/\\n/g,'\n'),
    issuer:env.IDENTITY_ISSUER,audience:env.IDENTITY_AUDIENCE,
    fin25ProofUrl:env.FIN25_INTERNAL_PROOF_URL,
    fin25InternalKey:env.FIN25_INTERNAL_API_KEY
  }
});
const respond=(res,status,value)=>{
  res.writeHead(status,{'content-type':'application/json; charset=utf-8',
    'cache-control':'no-store','x-content-type-options':'nosniff'});
  res.end(JSON.stringify(value));
};
const api=createServer(async(req,res)=>{
  try {
    const path=new URL(req.url || '/', 'http://localhost').pathname;
    if(req.method==='GET' && path==='/healthz') return respond(res,200,{status:'ok'});
    if(req.method==='GET' && path==='/v1/identity/me')
      return respond(res,200,await logic.me(req.headers.authorization));
    if(req.method!=='POST' || path!=='/v1/identity/session') return respond(res,404,{error:'Not found'});
    if(req.headers['content-type']?.split(';')[0].trim()!=='application/json')
      return respond(res,415,{error:'JSON required'});
    let length=0,body='';
    for await(const chunk of req) {
      length+=chunk.length;
      if(length>4096) throw new IdentityError(413,'Request too large');
      body+=chunk.toString('utf8');
    }
    let input;
    try {input=JSON.parse(body);} catch {throw new IdentityError(400,'Invalid JSON');}
    if(!input || typeof input!=='object' || Array.isArray(input)) throw new IdentityError(400,'Invalid JSON');
    const result=await logic.exchange(input);
    return respond(res,200,result);
  } catch(e) {
    if(e instanceof IdentityError) return respond(res,e.status,{error:e.message});
    // Never log body, phone, proof, credentials or SQL details.
    console.error('Identity request failed:',e?.name || 'InternalError');
    return respond(res,500,{error:'Identity service unavailable'});
  }
});
api.listen(port, env.IDENTITY_BIND_HOST || '127.0.0.1',
  ()=>console.info('P0 identity service listening (separate from FIN25)'));
const close=()=>api.close(()=>pool.end());
process.on('SIGTERM',close);process.on('SIGINT',close);
