#!/usr/bin/env node
// Safe, read-only trust check. Never prints private/public keys, tokens or passwords.
// Run from repository root: node scripts/check_identity_runtime_trust.mjs
import { readFileSync, existsSync } from 'node:fs';
import { createHash, createPrivateKey, createPublicKey } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const envPath=resolve(process.argv[2] || 'deploy/p0-identity/identity.runtime.env');
const report=(name,value)=>console.log(name+': '+value);
let failed=false;
const bad=(name,reason)=>{failed=true;report(name,'FAIL ('+reason+')');};
if(!existsSync(envPath)){
  bad('Local identity configuration','identity.runtime.env missing; no deployment is authorized');
  process.exitCode=1;
} else {
  // Docker Compose env_file syntax: KEY=value; retain escaped PEM line breaks.
  const cfg={};
  for(const [index,line] of readFileSync(envPath,'utf8').split(/\r?\n/).entries()){
    if(!line.trim() || line.trimStart().startsWith('#'))continue;
    const found=line.match(/^([A-Z][A-Z0-9_]*)=(.*)$/);
    if(!found){bad('Environment line '+(index+1),'invalid syntax');continue;}
    let value=found[2].trim();
    if(value.length>=2 && ((value.startsWith('"')&&value.endsWith('"'))||(value.startsWith("'")&&value.endsWith("'"))))value=value.slice(1,-1);
    cfg[found[1]]=value;
  }
  const pem=v=>v.replace(/\\n/g,'\n');
  const fingerprint=v=>createHash('sha256').update(createPublicKey(pem(v)).export({type:'spki',format:'der'})).digest('hex');
  const comparePair=(tag,priv,pub)=>{
    if(!cfg[priv]||!cfg[pub]||cfg[priv].startsWith('REPLACE_')||cfg[pub].startsWith('REPLACE_')){
      bad(tag,'private/public key not configured');return null;
    }
    try {
      const derived=createPublicKey(createPrivateKey(pem(cfg[priv]))).export({type:'spki',format:'der'});
      const expected=createPublicKey(pem(cfg[pub])).export({type:'spki',format:'der'});
      if(!derived.equals(expected)){bad(tag,'private and public keys do not match');return null;}
      report(tag,'PASS (matching RSA keypair)');
      return fingerprint(cfg[pub]);
    } catch {bad(tag,'invalid RSA key material');return null;}
  };
  const idKey=comparePair('FIN08 identity keypair','IDENTITY_PRIVATE_KEY_PEM','IDENTITY_PUBLIC_KEY_PEM');
  const otpKey=comparePair('FIN25 service keypair','FIN25_SIGNING_PRIVATE_KEY_PEM','FIN25_SIGNING_PUBLIC_KEY_PEM');
  const js=`const c=require('node:crypto');const p=process.env.KEY_PREFIX;const v=process.env[p+'_PUBLIC_KEY_PEM'];const i=process.env[p+'_ISSUER'];const a=process.env[p+'_AUDIENCE'];function key(x){return c.createHash('sha256').update(c.createPublicKey(x.replace(/\\\\n/g,'\\n')).export({type:'spki',format:'der'})).digest('hex')}function hash(x){return c.createHash('sha256').update(x).digest('hex')}console.log(JSON.stringify({key:v?key(v):null,issuer:i?hash(i):null,audience:a?hash(a):null}))`;
  const live=(container,prefix)=>{
    const command=js.replace('process.env.KEY_PREFIX',JSON.stringify(prefix));
    const result=spawnSync('docker',['exec','-i',container,'node','-'],{input:command,encoding:'utf8',timeout:12000,maxBuffer:100000});
    if(result.error || result.status!==0){bad(container,'Docker inspect unavailable; no change made');return null;}
    try{return JSON.parse(result.stdout.trim());}catch{bad(container,'invalid Docker result');return null;}
  };
  const checks=[
    ['FIN25','fin25-test-otp-1','JWT',otpKey,'FIN25_SIGNING_ISSUER','FIN25_SIGNING_AUDIENCE'],
    ['FIN08','maqwatilink-api-1','AUTH',idKey,'IDENTITY_ISSUER','IDENTITY_AUDIENCE']
  ];
  for(const [name,container,prefix,key,iss,aud] of checks){
    const v=live(container,prefix);
    if(!v)continue;
    const pairs=[['public RSA key',key,v.key],['issuer',cfg[iss] && createHash('sha256').update(cfg[iss]).digest('hex'),v.issuer],['audience',cfg[aud] && createHash('sha256').update(cfg[aud]).digest('hex'),v.audience]];
    for(const [label,expected,actual] of pairs){
      if(!expected||!actual||expected!==actual)bad(name+' '+label,'does not match running verifier');
      else report(name+' '+label,'PASS');
    }
  }
  if(!failed)report('FINAL','PASS: local signer configuration matches live FIN25/FIN08 trust; deployment not performed');
  else report('FINAL','BLOCKED: DO NOT DEPLOY or modify existing JWT settings');
  process.exitCode=failed?1:0;
}
