import { ApiError, page, encodeCursor, decodeCursor } from './validation.mjs';

/** Tenant-scoped merchant relationship list. The requester identity is always
 * obtained from an authenticated merchant JWT; no customer id is accepted. */
export async function listMerchantRelationships(pool, secret, actor, {limit,cursor}) {
  const n=page(limit);
  const decoded=decodeCursor(cursor,secret);
  if (decoded && (decoded.scope!=='merchant_relationships' || decoded.actor!==actor.id)) {
    throw new ApiError(422,'invalid_input','Cursor is invalid for this account or list');
  }
  const snapshot=decoded?.snapshot??(await pool.query('SELECT clock_timestamp()::text AS captured_at')).rows[0].captured_at;
  const {rows}=await pool.query(`
    SELECT r.id,r.contact_id,c.display_name AS contact_display_name,
      r.status,r.created_at,r.decided_at,r.created_at::text AS cursor_created_at
    FROM merchant_relationships r
    JOIN merchant_contacts c ON c.id=r.contact_id AND c.merchant_id=r.merchant_id
    WHERE r.merchant_id=$1
      AND r.created_at <= $2::timestamptz
      AND ($3::timestamptz IS NULL OR (r.created_at,r.id)<($3::timestamptz,$4::uuid))
    ORDER BY r.created_at DESC,r.id DESC LIMIT $5`,
    [actor.id,snapshot,decoded?.createdAt??null,decoded?.id??null,n+1]);
  const more=rows.length>n;
  const items=rows.slice(0,n).map(row=>({
    relationship_id:row.id,contact_id:row.contact_id,
    contact_display_name:row.contact_display_name,status:row.status,
    created_at:row.created_at,decided_at:row.decided_at,
  }));
  const last=rows[n-1];
  const next_cursor=more?encodeCursor({scope:'merchant_relationships',actor:actor.id,
    snapshot,createdAt:last.cursor_created_at,id:last.id},secret):null;
  return {items,next_cursor};
}
