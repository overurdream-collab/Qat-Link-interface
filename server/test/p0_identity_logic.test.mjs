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

function fixture({proofStatus=200,role='merchant',existing=null,failFinance=false}={}) {
  let consumed=0, inserted=0, current=existing, provisioned=0, failProvision=failFinance;
  const events=[];
  const pool={
    async connect(){return {release(){},async query(sql,args=[]){
      events.push(sql);
      if(sql==='BEGIN'||sql==='COMMIT'||sql==='ROLLBACK') return {rowCount:0,rows:[]};
      if(sql.startsWith('SELECT subject,role,display_name,finance_proof_reference,finance_provisioned_at FROM identity_accounts WHERE phone=')) return current?{rowCount:1,rows:[current]}:{rowCount:0,rows:[]};
      if(sql.startsWith('INSERT INTO identity_accounts')) {
        inserted++;
        current={subject:args[0],role:args[2],display_name:args[3],finance_proof_reference:args[4],finance_provisioned_at:null};
        return {rowCount:1,rows:[current]};
      }
      if(sql.startsWith('UPDATE identity_accounts'))return {rowCount:1,rows:[]};
      throw new Error('Unexpected statement');
    }};},
    async query(sql,args){
      events.push(sql);
      if(sql.startsWith('UPDATE identity_accounts SET finance_provisioned_at=')) {
        if(!current || current.subject!==args[0]) return {rowCount:0,rows:[]};
        current.finance_provisioned_at=new Date().toISOString();
        return {rowCount:1,rows:[{subject:current.subject}]};
      }
      if(sql.startsWith('UPDATE identity_accounts SET last_login_at=')) return {rowCount:1,rows:[]};
      if(sql.startsWith('SELECT subject,role,display_name,finance_provisioned_at FROM identity_accounts WHERE subject=')) {
        return current?.subject===args[0]?{rowCount:1,rows:[current]}:{rowCount:0,rows:[]};
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
  return {service:createIdentityLogic({pool,fetchImpl,settings,financeProvision}),requests,events,get consumed(){return consumed;},get inserted(){return inserted;},get provisioned(){return provisioned;},allowFinance(){failProvision=false;}};
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
  const f=fixture();const result=await f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي'});
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
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'merchant',displayName:'تاجر'}),e=>e.status===409);
  assert.equal(f.inserted,0);assert.equal(f.consumed,1);assert.ok(f.events.includes('ROLLBACK'));
});
test('missing signup role, supplier role and bogus proof fail closed',async()=>{
  const f=fixture();
  await assert.rejects(f.service.exchange({proofToken}),e=>e.status===409);
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'supplier'}),e=>e.status===400);
  await assert.rejects(f.service.exchange({proofToken:'malformed',requestedRole:'merchant'}),e=>e.status===400);
  assert.equal(f.consumed,1);
});
test('expired or rejected proof does not create identity or JWT',async()=>{
  const f=fixture({proofStatus:401});
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'customer'}),e=>e instanceof IdentityError && e.status===401);
  assert.equal(f.inserted,0);
});
test('tampered or expired account session is rejected',async()=>{
  const f=fixture({existing:{subject:'account-2',role:'customer',display_name:null}});
  const expired=signIdentityJwt({privateKey,issuer,audience,subject:'account-2',role:'customer',lifetimeSeconds:1,clock:()=>Date.now()-300000});
  await assert.rejects(f.service.me('Bearer '+expired),e=>e.status===401);
  const forged=signIdentityJwt({privateKey,issuer,audience,subject:'fake',role:'customer'});
  await assert.rejects(f.service.me('Bearer '+forged),e=>e.status===401);
});

test('financial provisioning failure prevents session but preserves stable identity for retry',async()=>{
  const f=fixture({failFinance:true});
  await assert.rejects(f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي'}),e=>e.status===503);
  assert.equal(f.provisioned,1);
  assert.ok(f.events.includes('COMMIT'));
  assert.equal(f.inserted,1);
  f.allowFinance();
  const recovered=await f.service.exchange({proofToken,requestedRole:'merchant',displayName:'متجر تجريبي'});
  assert.equal(recovered.account.role,'merchant');
  assert.equal(f.inserted,1);
  assert.equal(f.provisioned,2);
});

test('identity me rejects user who has not completed FIN08 provisioning',async()=>{
  const f=fixture({existing:{subject:'account-pending',role:'customer',display_name:null,finance_provisioned_at:null}});
  const token=signIdentityJwt({privateKey,issuer,audience,subject:'account-pending',role:'customer'});
  await assert.rejects(f.service.me('Bearer '+token),e=>e.status===401);
});
