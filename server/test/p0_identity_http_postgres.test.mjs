import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { Pool } from 'pg';
import { createVerifier } from '../src/auth.mjs';

const connectionString = process.env.IDENTITY_CI_DATABASE_URL;
const skip = !connectionString;

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function readJson(req) {
  let s = '';
  for await (const chunk of req) {
    s += chunk.toString('utf8');
    if (s.length > 4096) throw Error('Test payload too large');
  }
  return JSON.parse(s);
}
async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return server.address().port;
}
async function close(server) {
  if (server.listening) await new Promise(resolve => server.close(resolve));
}
async function freePort() {
  const temp = createServer();
  const port = await listen(temp);
  await close(temp);
  return port;
}

test('P0 HTTP + real PostgreSQL: synthetic FIN25 proof -> identity JWT -> FIN08, without any real SMS', {skip, timeout: 30000}, async t => {
  const pair = generateKeyPairSync('rsa',{modulusLength:2048});
  const privateKey = pair.privateKey.export({type:'pkcs8',format:'pem'});
  const publicKey = pair.publicKey.export({type:'spki',format:'pem'});
  const issuer='p0-ci-fin08-issuer',audience='p0-ci-fin08';
  const fin25Pair=generateKeyPairSync('rsa',{modulusLength:2048});
  const fin25PrivateKey=fin25Pair.privateKey.export({type:'pkcs8',format:'pem'});
  const fin25PublicKey=fin25Pair.publicKey.export({type:'spki',format:'pem'});
  const fin25Issuer='p0-ci-fin25-issuer',fin25Audience='p0-ci-fin25';
  const verify=createVerifier({publicKey,issuer,audience});
  const verifyFin25=createVerifier({publicKey:fin25PublicKey,issuer:fin25Issuer,audience:fin25Audience});
  const proofs=new Map();
  const finance=[];
  const pool=new Pool({connectionString});
  const fin25=createServer(async(req,res)=>{
    if(req.url!=='/v1/internal/otp/proof' || req.method!=='POST') {
      res.writeHead(404).end();return;
    }
    try {
      assert.equal(verifyFin25(req.headers.authorization).role,'identity_service');
      assert.equal(req.headers['x-internal-api-key'],'ci-internal-only');
      const {proofToken}=await readJson(req);
      const phone=proofs.get(proofToken);
      if(!phone) {res.writeHead(401).end(JSON.stringify({error:'expired'}));return;}
      proofs.delete(proofToken);
      res.writeHead(200,{'content-type':'application/json'}).end(JSON.stringify({verified:true,phone}));
    } catch {res.writeHead(403).end(); }
  });
  const fin08=createServer(async(req,res)=>{
    try {
      assert.equal(verify(req.headers.authorization).role,'identity_service');
      const body=await readJson(req);
      finance.push({path:req.url,body});
      res.writeHead(200,{'content-type':'application/json'}).end(JSON.stringify(
        req.url==='/v1/internal/merchant-profiles'
          ? {merchant_id:body.merchant_id}
          : {linked:false,conflict:false}
      ));
    } catch {res.writeHead(403).end();}
  });
  const procPort=await freePort();
  let proc;
  try {
    const fin25Port=await listen(fin25),fin08Port=await listen(fin08);
    proc=spawn(process.execPath,['src/identity_server.mjs'],{
      cwd:new URL('../',import.meta.url).pathname,
      env:{...process.env,
        IDENTITY_DATABASE_URL:connectionString,
        IDENTITY_PRIVATE_KEY_PEM:privateKey,
        IDENTITY_PUBLIC_KEY_PEM:publicKey,
        IDENTITY_ISSUER:issuer,IDENTITY_AUDIENCE:audience,
        FIN25_SIGNING_PRIVATE_KEY_PEM:fin25PrivateKey,FIN25_SIGNING_PUBLIC_KEY_PEM:fin25PublicKey,
        FIN25_SIGNING_ISSUER:fin25Issuer,FIN25_SIGNING_AUDIENCE:fin25Audience,
        FIN25_INTERNAL_PROOF_URL:`http://127.0.0.1:${fin25Port}/v1/internal/otp/proof`,
        FIN25_INTERNAL_API_KEY:'ci-internal-only',
        FIN08_INTERNAL_BASE_URL:`http://127.0.0.1:${fin08Port}/`,
        IDENTITY_PORT:String(procPort),IDENTITY_BIND_HOST:'127.0.0.1'},
      stdio:'ignore'
    });
    const origin=`http://127.0.0.1:${procPort}`;
    let ready=false;
    for(let i=0;i<60;i++) {
      if(proc.exitCode!==null) break;
      try {
        const response=await fetch(origin+'/healthz');
        if(response.ok) {ready=true;break;}
      }catch{}
      await sleep(120);
    }
    assert.equal(ready,true,'Identity service must start with migrated isolated schema');
    async function exchange({phone,role,name}) {
      const proofToken=randomUUID()+randomUUID();
      proofs.set(proofToken,phone);
      const payload={proofToken};
      if(role)payload.requestedRole=role;
      if(name)payload.displayName=name;
      const response=await fetch(origin+'/v1/identity/session',{
        method:'POST',headers:{'content-type':'application/json'},
        body:JSON.stringify(payload)
      });
      return {response,payload:await response.json()};
    }
    const m=await exchange({phone:'+967771234567',role:'merchant',name:'متجر اختبار'});
    assert.equal(m.response.status,200);
    assert.throws(()=>verifyFin25('Bearer '+m.payload.accessToken),'FIN08 user token must not pass FIN25 service verifier');
    assert.equal(verify('Bearer '+m.payload.accessToken).role,'merchant');
    assert.equal(finance[0].path,'/v1/internal/merchant-profiles');
    assert.equal(finance[0].body.merchant_id,m.payload.account.id);
    const merchantMe=await fetch(origin+'/v1/identity/me',{headers:{
      authorization:'Bearer '+m.payload.accessToken}});
    assert.equal(merchantMe.status,200);
    assert.equal((await merchantMe.json()).account.id,m.payload.account.id);

    const c=await exchange({phone:'+967772345678',role:'customer'});
    assert.equal(c.response.status,200);
    assert.equal(verify('Bearer '+c.payload.accessToken).role,'customer');
    assert.equal(finance[1].path,'/v1/internal/verified-phones');
    assert.equal(finance[1].body.customer_id,c.payload.account.id);
    assert.equal(finance[1].body.phone,'+967772345678');

    const escalation=await exchange({phone:'+967772345678',role:'merchant',name:'مزيف'});
    assert.equal(escalation.response.status,409);
    assert.equal(finance.length,2,'Role escalation must never invoke finance');

    const bad=await fetch(origin+'/v1/identity/session',{method:'POST',
      headers:{'content-type':'application/json'},
      body:JSON.stringify({proofToken:randomUUID()+randomUUID(),requestedRole:'merchant',displayName:'غير معروف'})});
    assert.equal(bad.status,401);
    const result=await pool.query(
      'SELECT role, finance_provisioned_at IS NOT NULL AS done FROM identity_accounts ORDER BY role');
    assert.equal(result.rowCount,2);
    assert.ok(result.rows.every(row=>row.done===true));
    assert.deepEqual(result.rows.map(row=>row.role),['customer','merchant']);
    t.diagnostic('PASS: 2 synthetic accounts with verified FIN08 provisioning; no SMS or financial approval generated');
  } finally {
    if(proc && proc.exitCode===null) {
      proc.kill('SIGTERM');
      await new Promise(resolve=>proc.once('exit',resolve));
    }
    await close(fin25);
    await close(fin08);
    await pool.end();
  }
});
