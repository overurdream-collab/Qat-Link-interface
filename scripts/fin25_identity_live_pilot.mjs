#!/usr/bin/env node
// Explicit operator-controlled FIN25 OTP -> Identity -> FIN08 pilot.
// Uses LOCAL Docker and localhost Identity, never a public unauthenticated OTP route.
// Does not log or persist the OTP, phone, proof, access token or keys.
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

const identity = 'http://127.0.0.1:8090';
const otpContainer = 'fin25-test-otp-1';
const dockerScript = String.raw\`
const fs=require('node:fs');
const input=JSON.parse(fs.readFileSync(0,'utf8'));
const port=process.env.FIN25_OTP_PORT||'8083';
fetch('http://127.0.0.1:'+port+input.path,{
 method:'POST',headers:{'content-type':'application/json'},
 body:JSON.stringify(input.body)
}).then(async r=>{
 const body=await r.json();
 process.stdout.write(JSON.stringify({status:r.status,body}));
}).catch(()=>{process.stderr.write('LOCAL_OTP_UNAVAILABLE');process.exitCode=1});
\`;

async function requestOtpService(path, body) {
  return new Promise((resolve, reject) => {
    const child=spawn('docker',['exec','-i',otpContainer,'node','-e',dockerScript],{
      stdio:['pipe','pipe','pipe'],windowsHide:true
    });
    let stdout='',stderr='';
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', s => {stdout+=s;if(stdout.length>16384)child.kill();});
    child.stderr.on('data', s => {stderr+=s;if(stderr.length>16384)child.kill();});
    child.on('error', () => reject(Error('Docker unavailable')));
    child.on('close', code => {
      if(code!==0) return reject(Error('Local FIN25 request failed'));
      try {resolve(JSON.parse(stdout));}
      catch {reject(Error('Invalid FIN25 response'));}
    });
    child.stdin.end(JSON.stringify({path,body}));
  });
}

function assert(value, message) {if(!value)throw Error(message);}

function hiddenInput(prompt) {
  assert(process.stdin.isTTY && typeof process.stdin.setRawMode==='function',
    'Use an interactive local terminal for secret entry.');
  return new Promise((resolve, reject)=>{
    let value='';
    process.stdout.write(prompt);
    function done(err){
      process.stdin.off('data',onData);
      process.stdin.setRawMode(false);
      process.stdout.write('\n');
      if(err)reject(err);else resolve(value.trim());
    }
    function onData(chunk) {
      for(const c of chunk.toString('utf8')) {
        if(c==='\r'||c==='\n')return done();
        if(c==='\u0003')return done(Error('Cancelled'));
        if(c==='\b'||c==='\u007f'){value=value.slice(0,-1);continue;}
        if(value.length<200)value+=c;
      }
    }
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on('data',onData);
  });
}

async function identityRequest(payload) {
  const response=await fetch(identity+'/v1/identity/session',{
    method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(payload),
    signal:AbortSignal.timeout(12000),redirect:'error'
  });
  return {status:response.status,body:await response.json()};
}

async function main() {
  console.log('=== Local FIN25 -> Identity -> FIN08 pilot ===');
  console.log('Exactly one real SMS request. No secrets printed or stored.');
  const ready=await fetch(identity+'/healthz',{signal:AbortSignal.timeout(8000)});
  assert(ready.status===200,'Local Identity is not ready; SMS was NOT requested.');

  // Do not provision new customer/merchant identities without separate consent.
  const rl=createInterface({input:process.stdin,output:process.stdout});
  let choice,name;
  try {
    choice=(await new Promise(r=>rl.question('Account: existing / customer / merchant: ',r))).trim().toLowerCase();
    assert(['existing','customer','merchant'].includes(choice),'Invalid role; SMS was NOT requested.');
    if(choice==='merchant'){
      name=(await new Promise(r=>rl.question('Merchant display name: ',r))).trim();
      assert(name.length>=2 && name.length<=160,'Invalid display name; SMS was NOT requested.');
    }
    if(choice!=='existing')console.log('WARNING: a successful OTP will provision a NEW '+choice+' account in live Identity/FIN08; no customer relationship/debt will be approved.');
    const ok=(await new Promise(r=>rl.question('Authorize exactly ONE real SMS and this account operation? Type YES: ',r))).trim();
    assert(ok==='YES','Cancelled before SMS.');
  } finally {rl.close();}

  const phone=await hiddenInput('Receiving number +967XXXXXXXXX (hidden): ');
  assert(/^\+967[0-9]{9}$/.test(phone),'Invalid phone; SMS was NOT requested.');
  const request=await requestOtpService('/v1/auth/otp/request',{phone});
  assert(request.status===202,'OTP request HTTP '+request.status+'; no automatic retry.');
  const requestId=request.body?.requestId;
  assert(typeof requestId==='string'&&/^[0-9a-f-]{36}$/i.test(requestId),'Invalid OTP request ID');
  console.log('HTTP 202: one OTP queued. No automatic retries. Enter its SMS code within five minutes.');
  const code=await hiddenInput('Six-digit OTP from receiving phone (hidden): ');
  assert(/^[0-9]{6}$/.test(code),'Invalid code; verification skipped.');
  const verified=await requestOtpService('/v1/auth/otp/verify',{requestId,code});
  assert(verified.status===200&&verified.body?.verified===true,'OTP verification HTTP '+verified.status);
  const proof=verified.body?.proofToken;
  assert(typeof proof==='string'&&/^[0-9a-f-]{72}$/i.test(proof),'Invalid one-use proof');
  console.log('FIN25: code verified. Redeeming proof to local Identity...');
  const session=await identityRequest({
    proofToken:proof,
    ...(choice!=='existing'?{requestedRole:choice}:{}),
    ...(choice==='merchant'?{displayName:name}:{})
  });
  assert(session.status===200,'Identity or FIN08 provisioning returned HTTP '+session.status+'. Proof cannot be reused.');
  const token=session.body?.accessToken;
  assert(typeof token==='string'&&token.length>50,'Identity did not return a valid access token');
  const me=await fetch(identity+'/v1/identity/me',{
    headers:{authorization:'Bearer '+token},signal:AbortSignal.timeout(12000)
  });
  assert(me.status===200,'Identity /me returned HTTP '+me.status);
  const account=await me.json();
  assert(account.account?.id===session.body.account?.id&&
    account.account?.role===session.body.account?.role,'Session/account mismatch');
  console.log('PASS: OTP verified -> Identity session -> /me; FIN08 provisioning accepted.');
  console.log('Account role: '+account.account.role);
}

main().catch(e=>{console.error('PILOT BLOCKED: '+e.message);process.exitCode=1;});
