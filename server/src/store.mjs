import { randomUUID } from 'node:crypto';
import { listMerchantContacts, listMerchantContactClaims } from './merchant_read.mjs';
import { ApiError, assertText, claimDigest, currency, decision, idempotencyKey, money, normalizePhone, page, uuid, encodeCursor, decodeCursor } from './validation.mjs';

const conflict = (message) => new ApiError(409, 'conflict', message);
const missing = () => new ApiError(404, 'not_found', 'Not found');

// Verified match evidence is required on EVERY disclosure/decision/posting.
// Even a previously issued link becomes unusable when phone evidence is
// revoked or conflicting accounts now claim the same phone number.
const verifiedJoin = `
  JOIN verified_contact_links vl ON vl.merchant_id = c.merchant_id AND vl.contact_id = c.id
  JOIN customer_phone_evidence ev ON ev.proof_reference = vl.proof_reference
    AND ev.customer_id = vl.customer_id AND ev.normalized_phone = c.normalized_phone
    AND ev.revoked_at IS NULL
  AND (SELECT COUNT(DISTINCT e.customer_id) FROM customer_phone_evidence e
       WHERE e.normalized_phone = c.normalized_phone AND e.revoked_at IS NULL) = 1`;

export class Fin08Store {
  constructor(pool, { cursorSecret }) {
    if (!cursorSecret || cursorSecret.length < 32) throw new Error('CURSOR_SECRET must have at least 32 characters');
    this.pool = pool;
    this.cursorSecret = cursorSecret;
  }
  async tx(fn) {
    const c = await this.pool.connect();
    try {
      await c.query('BEGIN');
      const out = await fn(c);
      await c.query('COMMIT');
      return out;
    } catch (err) {
      await c.query('ROLLBACK');
      if (err.code === '23505') throw conflict('An entry with these identifiers already exists');
      if (err.code === '23503') throw missing();
      throw err;
    } finally { c.release(); }
  }
  async lockRelationshipPair(c, merchantId, customerId) {
    // Same serializable guard whether the relationship row exists yet or not.
    await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1::text,0))',
      [`fin08:${merchantId}:${customerId}`]);
  }
  async audit(c, actorId, entityType, entityId, action, metadata = {}) {
    await c.query(`INSERT INTO fin08_audit_events
      (id,actor_id,entity_type,entity_id,action,metadata) VALUES($1,$2,$3,$4,$5,$6::jsonb)`,
      [randomUUID(), actorId, entityType, String(entityId), action, JSON.stringify(metadata)]);
  }
  async onboardMerchant(actor, body) {
    const merchantId = assertText(body.merchant_id, 'merchant_id', 200);
    const name = assertText(body.verified_display_name, 'verified_display_name', 160);
    if (name.length < 2) throw new ApiError(422, 'invalid_input', 'Merchant display name is too short');
    return this.tx(async c => {
      await c.query(`INSERT INTO merchant_profiles(merchant_id,verified_display_name) VALUES($1,$2)
        ON CONFLICT (merchant_id) DO UPDATE SET verified_display_name=EXCLUDED.verified_display_name`,[merchantId,name]);
      await this.audit(c, actor.id, 'merchant', merchantId, 'verified_profile_upserted');
      return { merchant_id: merchantId, verified_display_name: name };
    });
  }
  async createContact(actor, body) {
    const displayName = assertText(body.name, 'name', 160);
    if (displayName.length < 2) throw new ApiError(422, 'invalid_input', 'Contact name is too short');
    const phone = normalizePhone(body.phone);
    return this.tx(async c => {
      const id = randomUUID();
      const {rows} = await c.query(`INSERT INTO merchant_contacts(id,merchant_id,display_name,normalized_phone)
        VALUES($1,$2,$3,$4) RETURNING id,display_name AS name,normalized_phone AS phone,created_at`,[id,actor.id,displayName,phone]);
      await this.reconcilePhone(c, phone, actor.id);
      await this.audit(c, actor.id, 'merchant_contact', id, 'created');
      return rows[0];
    });
  }
  async reconcilePhone(c, phone, actorId) {
    // An owner change is NEVER automatic. Refresh a stale proof only when the
    // same verified customer remains the sole current owner of this number.
    await c.query(`INSERT INTO verified_contact_links(merchant_id,contact_id,customer_id,proof_reference)
      SELECT mc.merchant_id,mc.id,MIN(e.customer_id),MIN(e.proof_reference)
      FROM merchant_contacts mc JOIN customer_phone_evidence e
      ON e.normalized_phone=mc.normalized_phone AND e.revoked_at IS NULL
      WHERE mc.normalized_phone=$1
      GROUP BY mc.merchant_id,mc.id
      HAVING COUNT(DISTINCT e.customer_id)=1
      ON CONFLICT (merchant_id,contact_id) DO UPDATE
        SET proof_reference=EXCLUDED.proof_reference,linked_at=now()
        WHERE verified_contact_links.customer_id=EXCLUDED.customer_id
          AND NOT EXISTS (
            SELECT 1 FROM customer_phone_evidence old
            WHERE old.proof_reference=verified_contact_links.proof_reference
              AND old.revoked_at IS NULL
          )`,[phone]);
    // A private merchant contact is a declaration, not an approved relationship.
    // Only a uniquely verified account may receive a pending relationship request.
    const invitations=await c.query(`INSERT INTO merchant_relationships
      (id,merchant_id,customer_id,contact_id)
      SELECT gen_random_uuid(),vl.merchant_id,vl.customer_id,vl.contact_id
      FROM verified_contact_links vl
      JOIN merchant_contacts mc ON mc.id=vl.contact_id AND mc.merchant_id=vl.merchant_id
      JOIN customer_phone_evidence proof ON proof.proof_reference=vl.proof_reference
        AND proof.customer_id=vl.customer_id AND proof.normalized_phone=mc.normalized_phone
        AND proof.revoked_at IS NULL
      WHERE mc.normalized_phone=$1
        AND (SELECT COUNT(DISTINCT e.customer_id) FROM customer_phone_evidence e
          WHERE e.normalized_phone=mc.normalized_phone AND e.revoked_at IS NULL)=1
      ON CONFLICT (merchant_id,customer_id) DO NOTHING
      RETURNING id,merchant_id,customer_id`,[phone]);
    for(const item of invitations.rows) {
      await this.audit(c,actorId,'relationship',item.id,'pending_invitation_created_from_verified_contact',
        {merchant_id:item.merchant_id,customer_id:item.customer_id});
    }
  }
  async createClaim(actor, body, requestKey) {
    const contactId = uuid(body.contact_id, 'contact_id');
    const amount = money(body.amount);
    const unit = currency(body.currency);
    const description = body.description == null ? null : assertText(body.description, 'description', 500);
    const key = idempotencyKey(requestKey);
    const hash = claimDigest({contactId,amount,currency:unit,description});
    return this.tx(async c => {
      const contact = await c.query('SELECT id FROM merchant_contacts WHERE id=$1 AND merchant_id=$2',[contactId,actor.id]);
      if (!contact.rowCount) throw missing();
      const id = randomUUID();
      const {rows} = await c.query(`INSERT INTO merchant_claims(id,merchant_id,contact_id,amount,currency,description,idempotency_key,request_digest)
        VALUES($1,$2,$3,$4::numeric,$5,$6,$7,$8)
        ON CONFLICT (merchant_id,idempotency_key) DO NOTHING
        RETURNING id,contact_id,amount::text,currency,description,created_at`,[id,actor.id,contactId,amount,unit,description,key,hash]);
      if (rows.length) {
        await this.audit(c,actor.id,'merchant_claim',id,'created_unacknowledged');
        return {claim:rows[0],replayed:false};
      }
      const replay = await c.query(`SELECT id,contact_id,amount::text,currency,description,created_at,request_digest
        FROM merchant_claims WHERE merchant_id=$1 AND idempotency_key=$2`,[actor.id,key]);
      if (!replay.rowCount || replay.rows[0].request_digest !== hash) throw conflict('Idempotency-Key already used with different content');
      const {request_digest: omitted, ...claim} = replay.rows[0];
      return {claim,replayed:true};
    });
  }
  async verifyPhone(actor, body) {
    const customerId = assertText(body.customer_id, 'customer_id', 200);
    const phone = normalizePhone(body.phone);
    const proofRef = assertText(body.proof_reference,'proof_reference',240);
    // Only the identity service calls this AFTER its independent OTP/ownership checks.
    return this.tx(async c => {
      const result = await c.query(`INSERT INTO customer_phone_evidence
        (id,customer_id,normalized_phone,proof_reference) VALUES($1,$2,$3,$4)
        ON CONFLICT (proof_reference) DO NOTHING RETURNING id`,[randomUUID(),customerId,phone,proofRef]);
      if (!result.rowCount) {
        const prior = await c.query('SELECT customer_id,normalized_phone FROM customer_phone_evidence WHERE proof_reference=$1',[proofRef]);
        if (!prior.rowCount || prior.rows[0].customer_id!==customerId || prior.rows[0].normalized_phone!==phone) throw conflict('Proof reference already assigned');
      } else await this.audit(c,actor.id,'phone_proof',proofRef,'verified_evidence_added',{customer_id:customerId});
      await this.reconcilePhone(c,phone,actor.id);
      const owners = await c.query(`SELECT COUNT(DISTINCT customer_id)::int AS count FROM customer_phone_evidence
        WHERE normalized_phone=$1 AND revoked_at IS NULL`,[phone]);
      return { linked: Number(owners.rows[0].count)===1, conflict: Number(owners.rows[0].count)!==1 };
    });
  }
  async revokeProof(actor, body) {
    const proofRef = assertText(body.proof_reference,'proof_reference',240);
    return this.tx(async c => {
      const r = await c.query(`UPDATE customer_phone_evidence SET revoked_at=now()
        WHERE proof_reference=$1 AND revoked_at IS NULL RETURNING normalized_phone`,[proofRef]);
      if (r.rowCount) await this.audit(c,actor.id,'phone_proof',proofRef,'revoked');
      // Old links remain for audit, but are no longer valid for disclosure.
      return {revoked: Boolean(r.rowCount)};
    });
  }
  async claimsInbox(actor, {limit, cursor}) {
    const count = page(limit);
    const parsed = decodeCursor(cursor,this.cursorSecret);
    // Snapshot is server issued; never accept a user-supplied phone or identity.
    const snapshot = parsed?.snapshot ?? new Date().toISOString();
    const {rows} = await this.pool.query(`SELECT cl.id,cl.merchant_id,mp.verified_display_name AS merchant_display_name,
        cl.contact_id,cl.amount::text,cl.currency,cl.description,cl.created_at,
        cl.created_at::text AS cursor_created_at,
        d.decision, r.status AS relationship_status, fm.id AS movement_id
      FROM merchant_claims cl
      JOIN merchant_contacts c ON c.id=cl.contact_id AND c.merchant_id=cl.merchant_id
      ${verifiedJoin}
      JOIN merchant_profiles mp ON mp.merchant_id=cl.merchant_id
      LEFT JOIN customer_claim_decisions d ON d.claim_id=cl.id AND d.customer_id=vl.customer_id
      LEFT JOIN merchant_relationships r ON r.merchant_id=cl.merchant_id AND r.customer_id=vl.customer_id
      LEFT JOIN financial_movements fm ON fm.source_claim_id=cl.id AND fm.customer_id=vl.customer_id
      WHERE vl.customer_id=$1 AND cl.created_at <= $2::timestamptz
        AND ($3::timestamptz IS NULL OR (cl.created_at,cl.id)<($3::timestamptz,$4::uuid))
      ORDER BY cl.created_at DESC,cl.id DESC LIMIT $5`,
      [actor.id,snapshot,parsed?.createdAt??null,parsed?.id??null,count+1]);
    const hasNext=rows.length>count;
    const items=rows.slice(0,count).map(row=>({
      claim_id:row.id,merchant_id:row.merchant_id,merchant_display_name:row.merchant_display_name,
      amount:row.amount,currency:row.currency,description:row.description,created_at:row.created_at,
      stage:row.movement_id ? 'approved' : row.decision==='reject' ? 'rejected' :
        row.decision==='accept' && row.relationship_status==='approved' ? 'accepted_awaiting_posting' :
        row.decision==='accept' ? 'accepted_awaiting_relationship' : 'awaiting_review'
    }));
    const last=rows[count-1];
    const nextCursor=hasNext ? encodeCursor({snapshot,createdAt:last.cursor_created_at,id:last.id},this.cursorSecret):null;
    return {items,next_cursor:nextCursor};
  }
  async ensureEligible(c,claimId,customerId) {
    const {rows}=await c.query(`SELECT cl.id,cl.merchant_id,cl.contact_id,cl.amount,cl.currency
      FROM merchant_claims cl
      JOIN merchant_contacts c ON c.id=cl.contact_id AND c.merchant_id=cl.merchant_id
      ${verifiedJoin}
      WHERE cl.id=$1 AND vl.customer_id=$2 FOR UPDATE OF cl`,[claimId,customerId]);
    if (!rows.length) throw missing();
    return rows[0];
  }
  async postClaim(c,claimId,actorId) {
    // Single atomic ledger insertion, possible ONLY after independent claim
    // consent and the merchant/customer relationship has been approved.
    const {rows}=await c.query(`INSERT INTO financial_movements
      (id,source_claim_id,relationship_id,merchant_id,customer_id,amount,currency)
      SELECT $2,cl.id,r.id,cl.merchant_id,d.customer_id,cl.amount,cl.currency
      FROM merchant_claims cl
      JOIN customer_claim_decisions d ON d.claim_id=cl.id AND d.decision='accept'
      JOIN merchant_relationships r ON r.merchant_id=cl.merchant_id
        AND r.customer_id=d.customer_id AND r.status='approved'
      JOIN merchant_contacts c ON c.id=cl.contact_id AND c.merchant_id=cl.merchant_id
      ${verifiedJoin}
      WHERE cl.id=$1 AND vl.customer_id=d.customer_id
      ON CONFLICT (source_claim_id) DO NOTHING RETURNING id`,[claimId,randomUUID()]);
    if (rows.length) await this.audit(c,actorId,'merchant_claim',claimId,'posted_once_as_approved_debt');
    return rows.length>0;
  }
  async decideClaim(actor, claimId, body) {
    const id=uuid(claimId,'claim_id');
    const selected=decision(body.decision);
    return this.tx(async c=>{
      // Lock the merchant/customer pair BEFORE claim rows. This prevents
      // concurrent relation-approval and claim-approval transactions from
      // both missing the other's change and leaving a stranded accepted debt.
      const owner=await c.query('SELECT merchant_id FROM merchant_claims WHERE id=$1',[id]);
      if (!owner.rowCount) throw missing();
      await this.lockRelationshipPair(c,owner.rows[0].merchant_id,actor.id);
      const claim=await this.ensureEligible(c,id,actor.id);
      const r=await c.query(`INSERT INTO customer_claim_decisions(claim_id,merchant_id,customer_id,decision)
        VALUES($1,$2,$3,$4) ON CONFLICT (claim_id) DO NOTHING RETURNING decision`,[id,claim.merchant_id,actor.id,selected]);
      if (!r.rowCount) {
        const prior=await c.query('SELECT decision,customer_id FROM customer_claim_decisions WHERE claim_id=$1',[id]);
        if (!prior.rowCount || prior.rows[0].customer_id!==actor.id || prior.rows[0].decision!==selected) throw conflict('Claim already has a different decision');
      } else await this.audit(c,actor.id,'merchant_claim',id,`customer_${selected}`);
      const posted=selected==='accept' ? await this.postClaim(c,id,actor.id) : false;
      return {claim_id:id,decision:selected,ledger_posted:posted,recorded: Boolean(r.rowCount)};
    });
  }
  async requestRelationship(actor, body) {
    const contactId=uuid(body.contact_id,'contact_id');
    return this.tx(async c=>{
      const {rows}=await c.query(`SELECT vl.customer_id
        FROM merchant_contacts c ${verifiedJoin}
        WHERE c.merchant_id=$1 AND c.id=$2 FOR UPDATE OF c`,[actor.id,contactId]);
      if (!rows.length) throw missing();
      const customerId=rows[0].customer_id;
      const saved=await c.query(`INSERT INTO merchant_relationships(id,merchant_id,customer_id,contact_id)
        VALUES($1,$2,$3,$4) ON CONFLICT(merchant_id,customer_id) DO NOTHING RETURNING id,status`,[randomUUID(),actor.id,customerId,contactId]);
      // Historical verified contacts already create pending invitations.
      // Repeating a request must not recreate or reset accepted/rejected links.
      if(!saved.rowCount) {
        const prior=await c.query(
          'SELECT id,status FROM merchant_relationships WHERE merchant_id=$1 AND customer_id=$2',
          [actor.id,customerId]);
        if(!prior.rowCount) throw conflict('Relationship could not be created');
        return {relationship_id:prior.rows[0].id,status:prior.rows[0].status,already_exists:true};
      }
      await this.audit(c,actor.id,'relationship',saved.rows[0].id,'merchant_requested');
      return {relationship_id:saved.rows[0].id,status:'pending',already_exists:false};
    });
  }
  async customerRelationships(actor, {limit,cursor}) {
    const count=page(limit);
    const parsed=decodeCursor(cursor,this.cursorSecret);
    if(parsed && (parsed.scope!=='customer_relationships' || parsed.actor!==actor.id)) {
      throw new ApiError(422,'invalid_input','Cursor is not valid for this customer');
    }
    const snapshot=parsed?.snapshot ?? new Date().toISOString();
    const {rows}=await this.pool.query(`SELECT r.id,r.merchant_id,
        mp.verified_display_name AS merchant_display_name,
        r.status,r.created_at,r.decided_at,r.created_at::text AS cursor_created_at
      FROM merchant_relationships r
      JOIN merchant_contacts c ON c.id=r.contact_id AND c.merchant_id=r.merchant_id
      ${verifiedJoin}
      JOIN merchant_profiles mp ON mp.merchant_id=r.merchant_id
      WHERE r.customer_id=$1 AND vl.customer_id=r.customer_id
        AND r.created_at<=$2::timestamptz
        AND ($3::timestamptz IS NULL OR (r.created_at,r.id)<($3::timestamptz,$4::uuid))
      ORDER BY r.created_at DESC,r.id DESC LIMIT $5`,
      [actor.id,snapshot,parsed?.createdAt??null,parsed?.id??null,count+1]);
    const hasNext=rows.length>count;
    const items=rows.slice(0,count).map(row=>({
      relationship_id:row.id,merchant_id:row.merchant_id,
      merchant_display_name:row.merchant_display_name,
      status:row.status,created_at:row.created_at,decided_at:row.decided_at,
    }));
    const last=rows[count-1];
    const next_cursor=hasNext?encodeCursor({
      scope:'customer_relationships',actor:actor.id,snapshot,
      createdAt:last.cursor_created_at,id:last.id
    },this.cursorSecret):null;
    return {items,next_cursor};
  }
  async decideRelationship(actor, relationshipId, body) {
    const id=uuid(relationshipId,'relationship_id');
    const selected=decision(body.decision);
    return this.tx(async c=>{
      const pair=await c.query('SELECT merchant_id,customer_id FROM merchant_relationships WHERE id=$1 AND customer_id=$2',[id,actor.id]);
      if (!pair.rowCount) throw missing();
      await this.lockRelationshipPair(c,pair.rows[0].merchant_id,actor.id);
      const rel=await c.query(`SELECT r.* FROM merchant_relationships r
        JOIN merchant_contacts c ON c.id=r.contact_id AND c.merchant_id=r.merchant_id
        ${verifiedJoin} WHERE r.id=$1 AND r.customer_id=$2 FOR UPDATE OF r`,[id,actor.id]);
      if (!rel.rowCount) throw missing();
      const current=rel.rows[0];
      const wanted=selected==='accept'?'approved':'rejected';
      if (current.status!== 'pending' && current.status!==wanted) throw conflict('Relationship has already been decided differently');
      if (current.status==='pending') {
        await c.query('UPDATE merchant_relationships SET status=$2,decided_at=now() WHERE id=$1',[id,wanted]);
        await this.audit(c,actor.id,'relationship',id,`customer_${selected}`);
      }
      let posted=0;
      if (wanted==='approved') {
        const claimed=await c.query(`SELECT cl.id FROM merchant_claims cl
          JOIN customer_claim_decisions d ON d.claim_id=cl.id AND d.decision='accept'
          WHERE cl.merchant_id=$1 AND d.customer_id=$2`,[current.merchant_id,actor.id]);
        for(const claim of claimed.rows) if(await this.postClaim(c,claim.id,actor.id)) posted++;
      }
      return {relationship_id:id,status:wanted,newly_posted_debts:posted};
    });
  }
  // FIN-09 restoration reads use authenticated merchant identity, never client-supplied tenant IDs.
  async listContacts(actor, opts) {
    return listMerchantContacts(this.pool, this.cursorSecret, actor, opts);
  }
  async listContactClaims(actor, contactId, opts) {
    return listMerchantContactClaims(this.pool, this.cursorSecret, actor, contactId, opts);
  }
  async summary(actor) {
    const {rows}=await this.pool.query(`SELECT cl.currency,
      COALESCE(SUM(CASE WHEN fm.id IS NULL AND d.decision IS DISTINCT FROM 'reject'
        AND NOT EXISTS (SELECT 1 FROM verified_contact_links vl
          JOIN merchant_contacts c ON c.merchant_id=vl.merchant_id AND c.id=vl.contact_id
          JOIN customer_phone_evidence ev ON ev.proof_reference=vl.proof_reference
            AND ev.customer_id=vl.customer_id AND ev.normalized_phone=c.normalized_phone AND ev.revoked_at IS NULL
          WHERE vl.merchant_id=cl.merchant_id AND vl.contact_id=cl.contact_id
            AND (SELECT COUNT(DISTINCT owner.customer_id) FROM customer_phone_evidence owner
              WHERE owner.normalized_phone=c.normalized_phone AND owner.revoked_at IS NULL)=1)
        THEN cl.amount ELSE 0 END),0)::text AS outside_app,
      COALESCE(SUM(CASE WHEN fm.id IS NULL AND d.decision IS DISTINCT FROM 'reject'
        AND EXISTS (SELECT 1 FROM verified_contact_links vl
          JOIN merchant_contacts c ON c.merchant_id=vl.merchant_id AND c.id=vl.contact_id
          JOIN customer_phone_evidence ev ON ev.proof_reference=vl.proof_reference
            AND ev.customer_id=vl.customer_id AND ev.normalized_phone=c.normalized_phone AND ev.revoked_at IS NULL
          WHERE vl.merchant_id=cl.merchant_id AND vl.contact_id=cl.contact_id
            AND (SELECT COUNT(DISTINCT owner.customer_id) FROM customer_phone_evidence owner
              WHERE owner.normalized_phone=c.normalized_phone AND owner.revoked_at IS NULL)=1)
        THEN cl.amount ELSE 0 END),0)::text AS awaiting_customer_or_relationship,
      COALESCE(SUM(CASE WHEN fm.id IS NOT NULL THEN cl.amount ELSE 0 END),0)::text AS approved_from_claims
      FROM merchant_claims cl
      LEFT JOIN customer_claim_decisions d ON d.claim_id=cl.id
      LEFT JOIN financial_movements fm ON fm.source_claim_id=cl.id
      WHERE cl.merchant_id=$1 GROUP BY cl.currency ORDER BY cl.currency`,[actor.id]);
    return {currencies:rows,approved_scope:'pre_registration_claims_only_not_full_ledger'};
  }
}