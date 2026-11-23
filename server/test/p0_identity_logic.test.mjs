import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { createIdentityLogic, signIdentityJwt, IdentityError } from '../src/identity_logic.mjs';
import { createVerifier } from '../src/auth.mjs';

const pair=generateKeyPairSync('rsa',{modulusLength:2048});
const privateKey=pair.privateKey.export({type:'pkcs8',format:'pem'});
const publicKey=pair.publicKey.export({type:'spki',format:'pem'});
const issuer='qat-link-identity-test',audience='qat-link-financial-test';
const proofToken='11111111-1111-4111-8111-11111111111122222222-2222-4222-8222-222222222222';
const deviceId='33333333-3333-4333-8333-333333333333';
const otherDevice='44444444-4444-4444-8444-444444444444';

function fixture({proofStatus=200,role='merchant',existing=null,failFinance=false}={}) {
  let consumed=0, inserted=0, current=existing, provisioned=0, failProvision=failFinance;
  const events=[];
  const sessions=new Map();
  const accountDone=()=>Boolean(current?.finance_provisioned_at);
  function insertSession(args){
    const row={id:args[0],subject:args[1],role:args[2],refresh_hash:args[3],device_id:args[4],
      expires_at:new Date(Date.now()+30*86400000).toISOString(),revoked_at:null,rotated_at:null};
    sessions.set(row.id,row);
    return row;
  }
  function refreshRow(hash){
    const row=[...sessions.values()].find(s=>s.refresh_hash===hash && !s.revoked_at);
    if(!row) return null;
    return {...row,finance_provisioned_at:current?.subject===row.subject?current.finance_provisioned_at:null};
  }
  function meRow(subject,sid,role){
    const session=sessions.get(sid);
    if(!session || session.subject!==subject || session.role!==role || session.revoked_at) return null;
    if(new Date(session.expires_at).getTime()<=Date.now()) return null;
    if(current?.subject!==subject) return null;
    return {subject:current.subject,role:current.role,display_name:current.display_name,
      finance_provisioned_at:current.finance_provisioned_at};
  }
  const clientQuery=async(sql,args=[])=>{
    events.push(sql);
    if(sql==='BEGIN'||sql==='COMMIT'||sql==='ROLLBACK') return {rowCount:0,rows:[]};
    if(sql.startsWith('SELECT subject,role,display_name,finance_proof_reference,finance_provisioned_at FROM identity_accounts WHERE phone=')) return current?{rowCount:1,rows:[current]}:{rowCount:0,rows:[]};
    if(sql.startsWith('INSERT INTO identity_accounts')) {
      inserted++;
      current={subject:args[0],role:args[2],display_name:args[3],finance_proof_reference:args[4],finance_provisioned_at:null};
      return {rowCount:1,rows:[current]};
    }
    if(sql.startsWith('INSERT INTO identity_sessions')) {insertSession(args);return {rowCount:1,rows:[]};}
    if(sql.startsWith('SELECT s.id,s.subject,s.role,s.device_id,s.expires_at,a.finance_provisioned_at')) {
      const row=refreshRow(args[0]);
      return row?{rowCount:1,rows:[row]}:{rowCount:0,rows:[]};
    }
    if(sql.startsWith('UPDATE identity_sessions SET revoked_at=now(),rotated_at=now()')) {
      const row=sessions.get(args[0]);
      if(!row || row.revoked_at) return {rowCount:0,rows:[]};
      row.revoked_at=new Date().toISOString();row.rotated_at=row.revoked_at;
      return {rowCount:1,rows:[{id:row.id}]};
    }
    throw new Error('Unexpected client statement');
  };
  const pool={
    async connect(){return {release(){},query:clientQuery};},
    async query(sql,args){
      events.push(sql);
      if(sql.startsWith('UPDATE identity_accounts SET finance_provisioned_at=')) {
        if(!current || current.subject!==args[0]) return {rowCount:0,rows:[]};
        current.finance_provisioned_at=new Date().toISOString();
        return {rowCount:1,rows:[{subject:current.subject}]};
      }
      if(sql.startsWith('UPDATE identity_accounts SET last_login_at=')) return {rowCount:1,rows:[]};
      if(sql.startsWith('INSERT INTO identity_sessions')) {insertSession(args);return {rowCount:1,rows:[]};}
      if(sql.startsWith('SELECT a.subject,a.role,a.display_name,a.finance_provisioned_at')) {
        const row=meRow(args[0],args[1],args[2]);
        return row?{rowCount:1,rows:[row]}:{rowCount:0,rows:[]};
      }
      if(sql.startsWith('UPDATE identity_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE id=')) {
        const row=sessions.get(args[0]);
        if(row && row.subject===args[1] && !row.revoked_at) row.revoked_at=new Date().toISOString();
        return {rowCount:1,rows:[]};
      }
      if(sql.startsWith('UPDATE identity_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE refresh_hash=')) {
        for(const row of sessions.values()) {
          const subjectMatches=args.length<2 || row.subject===args[1];
          if(row.refresh_hash===args[0] && subjectMatches && !row.revoked_at) row.revoked_at=new Date().toISOString();
        }
        return {rowCount:1,rows:[]};
      }
      throw new Error('Unexpected statement');
    }
  };
  const requests=[];
  const fetchImpl=async (url,opts)=>{
    requests.push({url,auth:opts.headers.authorization,internalKey:opts.headers['x-internal-api-key'],body:JSON.parse(opts.body)});
    consumed++;
    return {ok:proofStatus===200,status:proofStatus,async json(){return {verified:true,phone:'+967771234567'};}};
  };
  const financeProvision=async ({account,phone})=>{
    provisioned++;
    assert.equal(phone,'+967771234567');
    if(failProvision) throw new IdentityError(503,'Finance unavailable');
  };
  const settings={privateKey,publicKey,issuer,audience,fin25Signing:{privateKey,issuer,audience},fin25ProofUrl:'http://fin25-test-otp:8083/v1/internal/otp/proof',fin25InternalKey:'test-key'};
  return {service:createIdentityLogic({pool,fetchImpl,settings,financeProvision}),requests,events,
    get consumed(){return consumed;},get inserted(){return inserted;},get provisioned(){return provisioned;},
    addSession(subject,role,{revoked=false,expired=false,device=deviceId}={}){
      const id='11111111-1111-4111-8111-111111111111';
      sessions.set(id,{id,subject,role,refresh_hash:'a'.repeat(64),device_id:device,
        expires_at:new Date(Date.now()+(expired?-86400000:86400000)).toISOString(),
        revoked_at:revoked?new Date().toISOString():null,rotated_at:null});
      return id;
    },
    allowFinance(){failProvision=false;}};
}
test('RS256 identity_service bearer is accepted and HS256 is refused',()=>{
  const bearer=signIdentityJwt({privateKey,issuer,audience,subject:'identity-svc',role:'identity_service',lifetimeSeconds:60});
  const verify=createVerifier({publicKey,issuer,audience});
  assert.equal(verify('Bearer '+bearer).role,'identity_service');
  const parts=bearer.split('.');
  const forged=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
  assert.throws(()=>verify('Bearer '+[forged,parts[1],parts[2]].join('.')));
});
test('valid proof creates one merchant identity, returns user JWT, checks role on me',async()=>{
  const f=fixture();const result=await f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي',deviceId});
  assert.equal(result.account.role,'merchant');
  assert.equal(f.inserted,1);assert.equal(f.consumed,1);assert.equal(f.provisioned,1);
  assert.equal(f.requests[0].internalKey,'test-key');
  assert.equal(f.requests[0].body.proofToken,proofToken);
  assert.equal(createVerifier({publicKey,issuer,audience})('Bearer '+f.requests[0].auth.split(' ')[1]).role,'identity_service');
  assert.equal(createVerifier({publicKey,issuer,audience})('Bearer '+result.accessToken).role,'merchant');
  assert.deepEqual((await f.service.me('Bearer '+result.accessToken)).account,result.account);
  assert.ok(f.events.includes('COMMIT'));
});
test('existing phone keeps stored role, rejects requested escalation even after proof',async()=>{
  const f=fixture({existing:{subject:'account-1',role:'customer',display_name:'عميل'}});
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'merchant',displayName:'تاجر',deviceId}),e=>e.status===409);
  assert.equal(f.inserted,0);assert.equal(f.consumed,1);assert.ok(f.events.includes('ROLLBACK'));
});
test('missing signup role, supplier role and bogus proof fail closed',async()=>{
  const f=fixture();
  await assert.rejects(f.service.exchange({proofToken,deviceId}),e=>e.status===409);
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'supplier',deviceId}),e=>e.status===400);
  await assert.rejects(f.service.exchange({proofToken:'malformed',requestedRole:'merchant'}),e=>e.status===400);
  assert.equal(f.consumed,1);
});
test('expired or rejected proof does not create identity or JWT',async()=>{
  const f=fixture({proofStatus:401});
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'customer',deviceId}),e=>e instanceof IdentityError && e.status===401);
  assert.equal(f.inserted,0);
});
test('tampered or expired account session is rejected',async()=>{
  const f=fixture({existing:{subject:'account-2',role:'customer',display_name:null}});
  const sid=f.addSession('account-2','customer');
  const expired=signIdentityJwt({privateKey,issuer,audience,subject:'account-2',role:'customer',sessionId:sid,lifetimeSeconds:1,clock:()=>Date.now()-300000});
  await assert.rejects(f.service.me('Bearer '+expired),e=>e.status===401);
  const forged=signIdentityJwt({privateKey,issuer,audience,subject:'fake',role:'customer',sessionId:sid});
  await assert.rejects(f.service.me('Bearer '+forged),e=>e.status===401);
  const noSession=signIdentityJwt({privateKey,issuer,audience,subject:'account-2',role:'customer'});
  await assert.rejects(f.service.me('Bearer '+noSession),e=>e.status===401);
});

test('refresh rotates a one-time token and logout revokes the new session',async()=>{
  const f=fixture();
  const first=await f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي',deviceId});
  assert.equal(typeof first.refreshToken,'string');
  assert.equal(first.refreshToken.length,43);
  assert.equal(first.refreshExpiresInSeconds,2592000);
  assert.equal((await f.service.me('Bearer '+first.accessToken)).account.role,'merchant');

  const second=await f.service.refresh({refreshToken:first.refreshToken,deviceId});
  assert.notEqual(second.accessToken,first.accessToken);
  assert.notEqual(second.refreshToken,first.refreshToken);
  assert.equal((await f.service.me('Bearer '+second.accessToken)).account.role,'merchant');
  await assert.rejects(f.service.me('Bearer '+first.accessToken),e=>e.status===401);
  await assert.rejects(f.service.refresh({refreshToken:first.refreshToken,deviceId}),e=>e.status===401);

  assert.deepEqual(await f.service.logout({header:'Bearer '+second.accessToken,refreshToken:second.refreshToken}),{revoked:true});
  await assert.rejects(f.service.me('Bearer '+second.accessToken),e=>e.status===401);
  await assert.rejects(f.service.refresh({refreshToken:second.refreshToken,deviceId}),e=>e.status===401);

  const third=await f.service.refresh({refreshToken:first.refreshToken,deviceId}).catch(()=>null);
  assert.equal(third,null);
  const fresh=await f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي',deviceId});
  assert.deepEqual(await f.service.logout({refreshToken:fresh.refreshToken}),{revoked:true});
  await assert.rejects(f.service.refresh({refreshToken:fresh.refreshToken,deviceId}),e=>e.status===401);
});

test('refresh is bound to the device that created the session',async()=>{
  const f=fixture();
  const first=await f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي',deviceId});
  await assert.rejects(f.service.refresh({refreshToken:first.refreshToken,deviceId:otherDevice}),e=>e.status===401);
  await assert.rejects(f.service.refresh({refreshToken:first.refreshToken}),e=>e.status===400);
  const same=await f.service.refresh({refreshToken:first.refreshToken,deviceId});
  assert.equal((await f.service.me('Bearer '+same.accessToken)).account.role,'merchant');
});

test('refresh rejects malformed or unknown tokens and logout stays idempotent',async()=>{
  const f=fixture({existing:{subject:'account-3',role:'customer',display_name:null}});
  await assert.rejects(f.service.refresh({refreshToken:'short',deviceId}),e=>e.status===401);
  await assert.rejects(f.service.refresh({refreshToken:'a'.repeat(43),deviceId}),e=>e.status===401);
  const sid=f.addSession('account-3','customer',{expired:true});
  const token=signIdentityJwt({privateKey,issuer,audience,subject:'account-3',role:'customer',sessionId:sid});
  assert.deepEqual(await f.service.logout({header:'Bearer '+token}),{revoked:true});
  assert.deepEqual(await f.service.logout({header:'Bearer '+token}),{revoked:true});
});

test('financial provisioning failure prevents session but preserves stable identity for retry',async()=>{
  const f=fixture({failFinance:true});
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي',deviceId}),e=>e.status===503);
  assert.equal(f.provisioned,1);
  assert.ok(f.events.includes('COMMIT'));
  assert.equal(f.inserted,1);
  f.allowFinance();
  const recovered=await f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي',deviceId});
  assert.equal(recovered.account.role,'merchant');
  assert.equal(f.inserted,1);
  assert.equal(f.provisioned,2);
});

test('identity me rejects user who has not completed FIN08 provisioning',async()=>{
  const f=fixture({existing:{subject:'account-pending',role:'customer',display_name:null,finance_provisioned_at:null}});
  const sid=f.addSession('account-pending','customer');
  const token=signIdentityJwt({privateKey,issuer,audience,subject:'account-pending',role:'customer',sessionId:sid});
  await assert.rejects(f.service.me('Bearer '+token),e=>e.status===401);
});
