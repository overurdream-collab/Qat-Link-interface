// P0 identity API is a separate process. It does NOT alter running FIN25 OTP/SMS.
import { createServer } from 'node:http';
import { createPrivateKey, createPublicKey } from 'node:crypto';
import { Pool } from 'pg';
import { createIdentityLogic, IdentityError } from './identity_logic.mjs';
import { createFinanceProvisioner } from './identity_finance_provisioner.mjs';
import { createIdentitySessionLimiter } from './identity_session_limiter.mjs';
import { createIdentityFinanceReadProxy } from './identity_fin08_read_proxy.mjs';

const env = process.env;
const required = [
  'IDENTITY_DATABASE_URL','IDENTITY_PRIVATE_KEY_PEM','IDENTITY_PUBLIC_KEY_PEM',
  'IDENTITY_ISSUER','IDENTITY_AUDIENCE','FIN25_INTERNAL_PROOF_URL','FIN25_INTERNAL_API_KEY',
  'FIN08_INTERNAL_BASE_URL',
  'FIN25_SIGNING_PRIVATE_KEY_PEM','FIN25_SIGNING_PUBLIC_KEY_PEM',
  'FIN25_SIGNING_ISSUER','FIN25_SIGNING_AUDIENCE'
];
for(const k of required) if(!env[k]) throw new Error('Missing identity configuration: '+k);
const pem = s => s.replace(/\\n/g,'\n');
// Refuse startup if signing keys do not match their corresponding verifier keys.
for (const [privateName, publicName] of [
  ['IDENTITY_PRIVATE_KEY_PEM','IDENTITY_PUBLIC_KEY_PEM'],
  ['FIN25_SIGNING_PRIVATE_KEY_PEM','FIN25_SIGNING_PUBLIC_KEY_PEM']
]) {
  const actual = createPublicKey(createPrivateKey(pem(env[privateName]))).export({type:'spki',format:'der'});
  const expected = createPublicKey(pem(env[publicName])).export({type:'spki',format:'der'});
  if (!actual.equals(expected)) throw new Error('Identity signing public/private key mismatch: '+publicName);
}
const port = Number(env.IDENTITY_PORT || 8090);
if(!Number.isInteger(port) || port<1 || port>65535) throw new Error('Invalid IDENTITY_PORT');
const pool = new Pool({connectionString:env.IDENTITY_DATABASE_URL,
  ssl:env.IDENTITY_PG_SSL==='true'?{rejectUnauthorized:true}:undefined,max:5});
const signing = {
  privateKey:pem(env.IDENTITY_PRIVATE_KEY_PEM),
  issuer:env.IDENTITY_ISSUER,audience:env.IDENTITY_AUDIENCE
};
const finance = createFinanceProvisioner({
  fetchImpl:fetch,
  settings:{...signing,financeBaseUrl:env.FIN08_INTERNAL_BASE_URL}
});
const logic = createIdentityLogic({
  pool,fetchImpl:fetch,financeProvision:finance.provision,
  settings:{
    privateKey:env.IDENTITY_PRIVATE_KEY_PEM.replace(/\\n/g,'\n'),
    publicKey:pem(env.IDENTITY_PUBLIC_KEY_PEM),
    issuer:env.IDENTITY_ISSUER,audience:env.IDENTITY_AUDIENCE,
    fin25ProofUrl:env.FIN25_INTERNAL_PROOF_URL,
    fin25InternalKey:env.FIN25_INTERNAL_API_KEY,
    fin25Signing:{
      privateKey:pem(env.FIN25_SIGNING_PRIVATE_KEY_PEM),
      issuer:env.FIN25_SIGNING_ISSUER,
      audience:env.FIN25_SIGNING_AUDIENCE
    }
  }
});
// A conservative per-TCP-peer safety budget. An edge-level, distributed limiter is
// still mandatory before public exposure; reverse proxies may share one peer IP.
const sessionLimiter = createIdentitySessionLimiter();
const financeRead = createIdentityFinanceReadProxy({fetchImpl: fetch, financeBaseUrl:env.FIN08_INTERNAL_BASE_URL});
const respond=(res,status,value,extraHeaders={})=>{
  res.writeHead(status,{'content-type':'application/json; charset=utf-8',
    'cache-control':'no-store','x-content-type-options':'nosniff',...extraHeaders});
  res.end(JSON.stringify(value));
};
const api=createServer(async(req,res)=>{
  try {
    const path=new URL(req.url || '/', 'http://localhost').pathname;
    if(req.method==='GET' && path==='/healthz') {
      // Database and schema must be present before accepting a phone proof.
      // Never reveal connection strings, table contents or key material.
      try {
        await pool.query('SELECT subject FROM identity_accounts LIMIT 0');
        return respond(res,200,{status:'ready'});
      } catch {
        return respond(res,503,{status:'unavailable'});
      }
    }
    if(req.method==='GET' && path==='/v1/identity/me')
      return respond(res,200,await logic.me(req.headers.authorization));
    // Read-only financial data through the already-networked Identity service.
    // Validate this session before calling FIN08; FIN08 also verifies its JWT.
    if(req.method==='GET' &&
      (path.startsWith('/v1/merchant/') || path.startsWith('/v1/customer/'))) {
      const account=(await logic.me(req.headers.authorization)).account;
      return respond(res,200,await financeRead({
        method:req.method,url:req.url,
        authorization:req.headers.authorization,account
      }));
    }
    if(req.method!=='POST' || path!=='/v1/identity/session') return respond(res,404,{error:'Not found'});
    if(req.headers['content-type']?.split(';')[0].trim()!=='application/json')
      return respond(res,415,{error:'JSON required'});
    // Never trust client-controlled Forwarded/X-Forwarded-For values here.
    const budget = sessionLimiter.check(req.socket.remoteAddress);
    if (!budget.allowed) {
      return respond(res,429,{error:'Too many session requests'},
        {'retry-after':String(budget.retryAfterSeconds)});
    }
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
