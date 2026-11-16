import { ApiError, page, encodeCursor, decodeCursor } from './validation.mjs';

/** Tenant-scoped customer relationship inbox. The requester identity is always
 * obtained from an authenticated customer JWT. No unverified phone matches. */
export async function listCustomerRelationships(pool, secret, actor, {limit,cursor}) {
  const n=page(limit);
  const decoded=decodeCursor(cursor,secret);
  if (decoded && (decoded.scope!=='customer_relationships' || decoded.actor!==actor.id)) {
    throw new ApiError(422,'invalid_input','Cursor is invalid for this account or list');
  }
  const snapshot=decoded?.snapshot??new Date().toISOString();
  const {rows}=await pool.query(`
    SELECT r.id,r.merchant_id,mp.verified_display_name AS merchant_display_name,
      r.status,r.created_at,r.decided_at,r.created_at::text AS cursor_created_at
    FROM merchant_relationships r
    JOIN merchant_contacts c ON c.id=r.contact_id AND c.merchant_id=r.merchant_id
    JOIN verified_contact_links vl ON vl.contact_id=c.id
      AND vl.merchant_id=c.merchant_id AND vl.customer_id=r.customer_id
    JOIN customer_phone_evidence ev ON ev.proof_reference=vl.proof_reference
      AND ev.customer_id=r.customer_id AND ev.normalized_phone=c.normalized_phone
      AND ev.revoked_at IS NULL
    JOIN merchant_profiles mp ON mp.merchant_id=r.merchant_id
    WHERE r.customer_id=$1
      AND (SELECT COUNT(DISTINCT evidence.customer_id)
        FROM customer_phone_evidence evidence
        WHERE evidence.normalized_phone=c.normalized_phone AND evidence.revoked_at IS NULL)=1
      AND r.created_at <= $2::timestamptz
      AND ($3::timestamptz IS NULL OR (r.created_at,r.id)<($3::timestamptz,$4::uuid))
    ORDER BY r.created_at DESC,r.id DESC LIMIT $5`,
    [actor.id,snapshot,decoded?.createdAt??null,decoded?.id??null,n+1]);
  const more=rows.length>n;
  const items=rows.slice(0,n).map(row=>({
    relationship_id:row.id,merchant_id:row.merchant_id,
    merchant_display_name:row.merchant_display_name,status:row.status,
    created_at:row.created_at,decided_at:row.decided_at,
  }));
  const last=rows[n-1];
  const next_cursor=more?encodeCursor({scope:'customer_relationships',actor:actor.id,
    snapshot,createdAt:last.cursor_created_at,id:last.id},secret):null;
  return {items,next_cursor};
}