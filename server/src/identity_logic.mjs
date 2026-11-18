import { createSign, randomUUID } from 'node:crypto';
import { createVerifier } from './auth.mjs';

export class IdentityError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export function signIdentityJwt({ privateKey, issuer, audience, subject, role, lifetimeSeconds = 900, clock = () => Date.now() }) {
  if (!privateKey || !issuer || !audience || !subject || !['identity_service','merchant','customer'].includes(role) ||
      !Number.isInteger(lifetimeSeconds) || lifetimeSeconds < 1 || lifetimeSeconds > 3600) {
    throw new Error('Invalid identity issuer configuration');
  }
  const now = Math.floor(clock() / 1000);
  const encode = v => Buffer.from(JSON.stringify(v)).toString('base64url');
  const h = encode({ alg:'RS256', typ:'JWT' });
  const p = encode({ iss:issuer, aud:audience, sub:subject, role, iat:now, exp:now+lifetimeSeconds, jti:randomUUID() });
  const sign = createSign('RSA-SHA256');
  sign.update(h+'.'+p); sign.end();
  return h+'.'+p+'.'+sign.sign(privateKey).toString('base64url');
}
export function createIdentityLogic({ pool, fetchImpl, settings, clock }) {
  const { privateKey, publicKey, issuer, audience, fin25ProofUrl, fin25InternalKey } = settings;
  if (!privateKey || !publicKey || !issuer || !audience || !fin25ProofUrl || !fin25InternalKey ||
      !/^https?:$/.test(new URL(fin25ProofUrl).protocol)) throw new Error('Identity configuration incomplete');
  const verify = createVerifier({ publicKey, issuer, audience });
  const issue = (subject,role,lifetimeSeconds=900) => signIdentityJwt({
    privateKey,issuer,audience,subject,role,lifetimeSeconds,clock
  });
  async function exchange({proofToken,requestedRole,displayName}) {
    if (typeof proofToken !== 'string' || !/^[a-f0-9-]{72}$/i.test(proofToken)) throw new IdentityError(400,'Invalid proof');
    if (requestedRole !== undefined && !['merchant','customer'].includes(requestedRole)) throw new IdentityError(400,'Invalid role');
    if (displayName !== undefined && (typeof displayName !== 'string' || displayName.trim().length < 2 || displayName.trim().length > 160))
      throw new IdentityError(400,'Invalid display name');
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    let response;
    try {
      response = await fetchImpl(fin25ProofUrl,{
        method:'POST',
        headers:{
          'content-type':'application/json',
          'authorization':'Bearer '+issue('maqwati-identity-service','identity_service',60),
          'x-internal-api-key':fin25InternalKey
        },
        body:JSON.stringify({proofToken}), signal:controller.signal, redirect:'error'
      });
    } catch { throw new IdentityError(503,'Identity proof service unavailable'); }
    finally { clearTimeout(timeout); }
    if(!response.ok) {
      if(response.status===400 || response.status===401 || response.status===403) throw new IdentityError(401,'Invalid or expired proof');
      throw new IdentityError(503,'Identity proof service unavailable');
    }
    let proof;
    try { proof=await response.json(); } catch {throw new IdentityError(502,'Invalid proof response');}
    if(proof?.verified !== true || typeof proof.phone !== 'string' || !/^\+967[0-9]{9}$/.test(proof.phone))
      throw new IdentityError(502,'Invalid proof response');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const existing = await client.query('SELECT subject,role,display_name FROM identity_accounts WHERE phone=$1 FOR UPDATE',[proof.phone]);
      let account;
      if(existing.rowCount) {
        account = existing.rows[0];
        if(requestedRole !== undefined && requestedRole !== account.role)
          throw new IdentityError(409,'This phone already belongs to another account role');
      } else {
        if(!requestedRole) throw new IdentityError(409,'Account registration required');
        if(requestedRole==='merchant' && !displayName?.trim()) throw new IdentityError(400,'Merchant display name required');
        const subject=randomUUID();
        const inserted=await client.query(
          'INSERT INTO identity_accounts(subject,phone,role,display_name) VALUES($1,$2,$3,$4) ON CONFLICT (phone) DO NOTHING RETURNING subject,role,display_name',
          [subject,proof.phone,requestedRole,displayName?.trim() || null]);
        if(!inserted.rowCount) throw new IdentityError(409,'Concurrent account registration; request new OTP');
        account=inserted.rows[0];
      }
      await client.query('UPDATE identity_accounts SET last_login_at=now() WHERE subject=$1',[account.subject]);
      await client.query('COMMIT');
      return {accessToken:issue(account.subject,account.role), tokenType:'Bearer', expiresInSeconds:900,
        account:{id:account.subject,role:account.role,displayName:account.display_name}};
    } catch(e) {await client.query('ROLLBACK');throw e;} finally {client.release();}
  }
  async function me(header) {
    let actor;
    try {actor=verify(header);}catch {throw new IdentityError(401,'Invalid or expired session');}
    if(!['merchant','customer'].includes(actor.role)) throw new IdentityError(403,'Not an account session');
    const result=await pool.query('SELECT subject,role,display_name FROM identity_accounts WHERE subject=$1',[actor.id]);
    if(result.rowCount!==1 || result.rows[0].role!==actor.role) throw new IdentityError(401,'Session account mismatch');
    const row=result.rows[0];
    return {account:{id:row.subject,role:row.role,displayName:row.display_name}};
  }
  return {exchange,me};
}
