import { createHash, createSign, randomBytes, randomUUID } from 'node:crypto';
import { createVerifier } from './auth.mjs';

const REFRESH_TTL_SECONDS = 30 * 24 * 60 * 60;
const UUID = /^[a-f0-9-]{36}$/i;

export class IdentityError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export function signIdentityJwt({ privateKey, issuer, audience, subject, role, sessionId, lifetimeSeconds = 900, clock = () => Date.now() }) {
  if (!privateKey || !issuer || !audience || !subject || !['identity_service','merchant','customer'].includes(role) ||
      !Number.isInteger(lifetimeSeconds) || lifetimeSeconds < 1 || lifetimeSeconds > 3600 ||
      (sessionId !== undefined && (typeof sessionId !== 'string' || !UUID.test(sessionId)))) {
    throw new Error('Invalid identity issuer configuration');
  }
  const now = Math.floor(clock() / 1000);
  const encode = v => Buffer.from(JSON.stringify(v)).toString('base64url');
  const h = encode({ alg:'RS256', typ:'JWT' });
  const p = encode({ iss:issuer, aud:audience, sub:subject, role,
    ...(sessionId ? {sid:sessionId} : {}),
    iat:now, exp:now+lifetimeSeconds, jti:randomUUID() });
  const sign = createSign('RSA-SHA256');
  sign.update(h+'.'+p); sign.end();
  return h+'.'+p+'.'+sign.sign(privateKey).toString('base64url');
}
export function createIdentityLogic({ pool, fetchImpl, settings, clock, financeProvision }) {
  const { privateKey, publicKey, issuer, audience, fin25ProofUrl, fin25InternalKey, fin25Signing } = settings;
  if (!privateKey || !publicKey || !issuer || !audience || !fin25ProofUrl || !fin25InternalKey ||
      !/^https?:$/.test(new URL(fin25ProofUrl).protocol)) throw new Error('Identity configuration incomplete');
  if(typeof financeProvision !== 'function') throw new Error('Verified FIN08 provisioner required');
  if (!fin25Signing?.privateKey || !fin25Signing?.issuer || !fin25Signing?.audience)
    throw new Error('Dedicated FIN25 service signing configuration required');
  const verify = createVerifier({ publicKey, issuer, audience });
  const issue = (subject,role,sessionId,lifetimeSeconds=900) => signIdentityJwt({
    privateKey,issuer,audience,subject,role,sessionId,lifetimeSeconds,clock
  });
  const hashRefresh = token => createHash('sha256').update(token).digest('hex');
  const newRefreshToken = () => randomBytes(32).toString('base64url');
  async function createSession(db, subject, role, deviceId) {
    const id = randomUUID();
    const refreshToken = newRefreshToken();
    await db.query(
      `INSERT INTO identity_sessions(id,subject,role,refresh_hash,device_id,expires_at)
       VALUES($1,$2,$3,$4,$5,now()+interval '${REFRESH_TTL_SECONDS} seconds')`,
      [id,subject,role,hashRefresh(refreshToken),deviceId]);
    return {id,subject,role,refreshToken,deviceId};
  }
  async function exchange({proofToken,requestedRole,displayName,deviceId}) {
    if (typeof proofToken !== 'string' || !/^[a-f0-9-]{72}$/i.test(proofToken)) throw new IdentityError(400,'Invalid proof');
    if (requestedRole !== undefined && !['merchant','customer'].includes(requestedRole)) throw new IdentityError(400,'Invalid role');
    if (displayName !== undefined && (typeof displayName !== 'string' || displayName.trim().length < 2 || displayName.trim().length > 160))
      throw new IdentityError(400,'Invalid display name');
    if (typeof deviceId !== 'string' || !UUID.test(deviceId)) throw new IdentityError(400,'Invalid device id');
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    let response;
    try {
      response = await fetchImpl(fin25ProofUrl,{
        method:'POST',
        headers:{
          'content-type':'application/json',
          'authorization':'Bearer '+signIdentityJwt({ ...fin25Signing, subject:'maqwati-identity-service', role:'identity_service', lifetimeSeconds:60, clock }),
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
    // Commit stable subject/reference before cross-service provisioning so that
    // retries after a network error use the SAME idempotent identity.
    const client = await pool.connect();
    let account;
    try {
      await client.query('BEGIN');
      const existing = await client.query(
        'SELECT subject,role,display_name,finance_proof_reference,finance_provisioned_at FROM identity_accounts WHERE phone=$1 FOR UPDATE',
        [proof.phone]);
      if(existing.rowCount) {
        account = existing.rows[0];
        if(requestedRole !== undefined && requestedRole !== account.role)
          throw new IdentityError(409,'This phone already belongs to another account role');
      } else {
        if(!requestedRole) throw new IdentityError(409,'Account registration required');
        if(requestedRole==='merchant' && !displayName?.trim())
          throw new IdentityError(400,'Merchant display name required');
        const inserted=await client.query(
          'INSERT INTO identity_accounts(subject,phone,role,display_name,finance_proof_reference) VALUES($1,$2,$3,$4,$5) ON CONFLICT (phone) DO NOTHING RETURNING subject,role,display_name,finance_proof_reference,finance_provisioned_at',
          [randomUUID(),proof.phone,requestedRole,displayName?.trim() || null,randomUUID()]);
        if(!inserted.rowCount) throw new IdentityError(409,'Concurrent registration; request new OTP');
        account=inserted.rows[0];
      }
      await client.query('COMMIT');
    } catch(e) {
      try { await client.query('ROLLBACK'); } catch {}
      throw e;
    } finally { client.release(); }

    if(!account.finance_provisioned_at) {
      // Idempotent remote update; a lost ACK can be retried with the stable
      // finance_proof_reference after a new, valid OTP. No JWT before success.
      await financeProvision({account,phone:proof.phone});
      const mark=await pool.query(
        'UPDATE identity_accounts SET finance_provisioned_at=now() WHERE subject=$1 RETURNING subject',
        [account.subject]);
      if(mark.rowCount!==1) throw new IdentityError(503,'Account provisioning state unavailable');
    }
    await pool.query('UPDATE identity_accounts SET last_login_at=now() WHERE subject=$1',[account.subject]);
    let session;
    try { session=await createSession(pool,account.subject,account.role,deviceId); }
    catch { throw new IdentityError(503,'Session store unavailable'); }
    return {accessToken:issue(account.subject,account.role,session.id), tokenType:'Bearer',
      expiresInSeconds:900, refreshToken:session.refreshToken, refreshExpiresInSeconds:REFRESH_TTL_SECONDS,
      account:{id:account.subject,role:account.role,displayName:account.display_name}};
  }
  async function me(header) {
    let actor;
    try {actor=verify(header);}catch {throw new IdentityError(401,'Invalid or expired session');}
    if(!['merchant','customer'].includes(actor.role) || typeof actor.sid !== 'string')
      throw new IdentityError(401,'Invalid or expired session');
    const result=await pool.query(
      `SELECT a.subject,a.role,a.display_name,a.finance_provisioned_at
       FROM identity_accounts a JOIN identity_sessions s ON s.subject=a.subject
       WHERE a.subject=$1 AND s.id=$2 AND s.role=$3
         AND s.revoked_at IS NULL AND s.expires_at>now()`,[actor.id,actor.sid,actor.role]);
    if(result.rowCount!==1 || result.rows[0].role!==actor.role || !result.rows[0].finance_provisioned_at)
      throw new IdentityError(401,'Session account mismatch');
    const row=result.rows[0];
    return {account:{id:row.subject,role:row.role,displayName:row.display_name}};
  }
  async function refresh({refreshToken,deviceId}) {
    if(typeof refreshToken!=='string' || !/^[A-Za-z0-9_-]{43}$/.test(refreshToken))
      throw new IdentityError(401,'Invalid or expired refresh token');
    if(typeof deviceId!=='string' || !UUID.test(deviceId))
      throw new IdentityError(400,'Invalid device id');
    const client=await pool.connect();
    let next;
    try {
      await client.query('BEGIN');
      const found=await client.query(
        `SELECT s.id,s.subject,s.role,s.device_id,s.expires_at,a.finance_provisioned_at
         FROM identity_sessions s JOIN identity_accounts a ON a.subject=s.subject
         WHERE s.refresh_hash=$1 AND s.revoked_at IS NULL FOR UPDATE`,[hashRefresh(refreshToken)]);
      if(found.rowCount!==1) throw new IdentityError(401,'Invalid or expired refresh token');
      const row=found.rows[0];
      if(!row.finance_provisioned_at || new Date(row.expires_at).getTime()<=Date.now() ||
         row.device_id!==deviceId)
        throw new IdentityError(401,'Invalid or expired refresh token');
      const revoked=await client.query(
        'UPDATE identity_sessions SET revoked_at=now(),rotated_at=now() WHERE id=$1 AND revoked_at IS NULL RETURNING id',
        [row.id]);
      if(revoked.rowCount!==1) throw new IdentityError(401,'Invalid or expired refresh token');
      next=await createSession(client,row.subject,row.role,deviceId);
      await client.query('COMMIT');
    } catch(e) {
      try { await client.query('ROLLBACK'); } catch {}
      throw e;
    } finally { client.release(); }
    return {accessToken:issue(next.subject,next.role,next.id), tokenType:'Bearer',
      expiresInSeconds:900, refreshToken:next.refreshToken, refreshExpiresInSeconds:REFRESH_TTL_SECONDS};
  }
  async function logout({header,refreshToken}) {
    let actor=null;
    try {actor=verify(header);}catch {actor=null;}
    const hasRefresh=typeof refreshToken==='string' && /^[A-Za-z0-9_-]{43}$/.test(refreshToken);
    if(!actor && !hasRefresh) throw new IdentityError(401,'Invalid or expired session');
    if(actor && typeof actor.sid==='string') {
      await pool.query(
        'UPDATE identity_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE id=$1 AND subject=$2',
        [actor.sid,actor.id]);
    }
    if(hasRefresh) {
      // Possession of the one-time refresh token is sufficient to revoke it,
      // so an expired access token cannot strand a still-valid refresh token.
      if(actor) {
        await pool.query(
          'UPDATE identity_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE refresh_hash=$1 AND subject=$2',
          [hashRefresh(refreshToken),actor.id]);
      } else {
        await pool.query(
          'UPDATE identity_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE refresh_hash=$1',
          [hashRefresh(refreshToken)]);
      }
    }
    return {revoked:true};
  }
  return {exchange,me,refresh,logout};
}
