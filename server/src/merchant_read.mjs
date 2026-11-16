import { ApiError, page, uuid, encodeCursor, decodeCursor } from './validation.mjs';

// Merchant-only, read-only FIN-09 API. The caller is authenticated in http.mjs;
// the merchant scope ALWAYS comes from actor.id rather than a query parameter.
function cursorFor(encoded, secret, actor, scope) {
  const decoded = decodeCursor(encoded, secret);
  if (decoded && (decoded.scope !== scope || decoded.actor !== actor.id)) {
    throw new ApiError(422, 'invalid_input', 'Cursor is not valid for this account or list');
  }
  return decoded;
}

function packPage(rows, limit, snapshot, secret, actor, scope, map) {
  const hasMore = rows.length > limit;
  const items = rows.slice(0, limit).map(map);
  const tail = rows[limit - 1];
  const nextCursor = hasMore ? encodeCursor({
    scope, actor: actor.id, snapshot,
    createdAt: new Date(tail.created_at).toISOString(), id: tail.id,
  }, secret) : null;
  return { items, next_cursor: nextCursor };
}

export async function listMerchantContacts(pool, secret, actor, { limit, cursor }) {
  const count = page(limit);
  const parsed = cursorFor(cursor, secret, actor, 'merchant_contacts');
  const snapshot = parsed?.snapshot ?? new Date().toISOString();
  const { rows } = await pool.query(`
    SELECT id,display_name AS name,normalized_phone AS phone,created_at
    FROM merchant_contacts
    WHERE merchant_id=$1 AND created_at <= $2::timestamptz
      AND ($3::timestamptz IS NULL OR (created_at,id)<($3::timestamptz,$4::uuid))
    ORDER BY created_at DESC,id DESC LIMIT $5`,
    [actor.id, snapshot, parsed?.createdAt ?? null, parsed?.id ?? null, count + 1]);
  return packPage(rows,count,snapshot,secret,actor,'merchant_contacts',row=>({
    contact_id:row.id, name:row.name, phone:row.phone, created_at:row.created_at,
  }));
}

export async function listMerchantContactClaims(pool, secret, actor, contactId, { limit, cursor }) {
  const id = uuid(contactId, 'contact_id');
  const count = page(limit);
  const scope = `merchant_contact_claims:${id}`;
  const parsed = cursorFor(cursor, secret, actor, scope);
  const snapshot = parsed?.snapshot ?? new Date().toISOString();
  const contact = await pool.query(`SELECT 1 FROM merchant_contacts WHERE id=$1 AND merchant_id=$2`,
    [id, actor.id]);
  if (!contact.rowCount) throw new ApiError(404,'not_found','Not found');
  const { rows } = await pool.query(`
    SELECT cl.id,cl.contact_id,cl.amount::text,cl.currency,cl.description,cl.created_at,
      d.decision, r.status AS relationship_status, fm.id AS movement_id,
      (ev.id IS NOT NULL AND
        (SELECT COUNT(DISTINCT proof.customer_id) FROM customer_phone_evidence proof
         WHERE proof.normalized_phone=mc.normalized_phone AND proof.revoked_at IS NULL)=1) AS verified
    FROM merchant_claims cl
    JOIN merchant_contacts mc ON mc.id=cl.contact_id AND mc.merchant_id=cl.merchant_id
    LEFT JOIN verified_contact_links vl ON vl.contact_id=mc.id AND vl.merchant_id=mc.merchant_id
    LEFT JOIN customer_phone_evidence ev ON ev.proof_reference=vl.proof_reference
      AND ev.customer_id=vl.customer_id AND ev.normalized_phone=mc.normalized_phone
      AND ev.revoked_at IS NULL
    LEFT JOIN customer_claim_decisions d ON d.claim_id=cl.id
    LEFT JOIN merchant_relationships r ON r.merchant_id=cl.merchant_id
      AND r.customer_id=vl.customer_id
    LEFT JOIN financial_movements fm ON fm.source_claim_id=cl.id
    WHERE cl.merchant_id=$1 AND cl.contact_id=$2 AND cl.created_at <= $3::timestamptz
      AND ($4::timestamptz IS NULL OR (cl.created_at,cl.id)<($4::timestamptz,$5::uuid))
    ORDER BY cl.created_at DESC,cl.id DESC LIMIT $6`,
    [actor.id,id,snapshot,parsed?.createdAt ?? null,parsed?.id ?? null,count + 1]);
  return packPage(rows,count,snapshot,secret,actor,scope,row=>({
    claim_id:row.id,contact_id:row.contact_id,amount:row.amount,currency:row.currency,
    description:row.description,created_at:row.created_at,
    stage: row.movement_id ? 'approved' :
      row.decision==='reject' ? 'rejected' :
      !row.verified ? 'outside_app' :
      row.decision==='accept' && row.relationship_status==='approved' ? 'accepted_awaiting_posting' :
      row.decision==='accept' ? 'accepted_awaiting_relationship' : 'awaiting_review',
  }));
}