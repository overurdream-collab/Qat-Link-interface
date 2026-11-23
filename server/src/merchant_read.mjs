import { createHash } from 'node:crypto';
import { ApiError, page, uuid, currency as currencyCode, encodeCursor, decodeCursor } from './validation.mjs';

// Merchant-only, read-only FIN-09 API. The caller is authenticated in http.mjs;
// the merchant scope ALWAYS comes from actor.id rather than a query parameter.
function cursorFor(encoded, secret, actor, scope) {
  const decoded = decodeCursor(encoded, secret);
  if (decoded && (decoded.scope !== scope || decoded.actor !== actor.id)) {
    throw new ApiError(422, 'invalid_input', 'Cursor is not valid for this account or list');
  }
  return decoded;
}

function searchTerm(raw) {
  if (raw == null) return null;
  const value = String(raw).trim();
  if (!value) return null;
  if (value.length > 80) throw new ApiError(422, 'invalid_input', 'Search term is too long');
  if (/[\u0000-\u001f]/.test(value)) throw new ApiError(422, 'invalid_input', 'Search term contains control characters');
  return value;
}

function scopeFor(base, { term, type, currency }) {
  const parts = [base];
  if (term) parts.push('q:' + createHash('sha256').update(term.normalize('NFKC')).digest('hex'));
  if (type) parts.push('t:' + type);
  if (currency) parts.push('c:' + currency);
  return parts.join(':');
}

function dateBound(raw, name, { endExclusive = false } = {}) {
  if (raw == null || raw === '') return null;
  if (typeof raw !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new ApiError(422, 'invalid_input', name + ' must be YYYY-MM-DD');
  }
  const start = Date.parse(raw + 'T00:00:00.000Z');
  if (!Number.isFinite(start) || new Date(start).toISOString().slice(0, 10) !== raw) {
    throw new ApiError(422, 'invalid_input', name + ' is not a valid date');
  }
  return endExclusive
    ? new Date(start + 86_400_000).toISOString()
    : new Date(start).toISOString();
}

function claimSort(raw) {
  if (raw == null || raw === '') return 'newest';
  if (!['newest', 'oldest', 'amount_desc', 'amount_asc'].includes(raw)) {
    throw new ApiError(422, 'invalid_input', 'sort is not supported');
  }
  return raw;
}

function claimType(raw) {
  if (raw == null || raw === '') return null;
  if (raw !== 'debt' && raw !== 'payment') throw new ApiError(422, 'invalid_input', 'type must be debt or payment');
  return raw;
}

function optionalCurrency(raw) {
  if (raw == null || raw === '') return null;
  return currencyCode(raw);
}

function packClaimPage(rows, limit, snapshot, secret, actor, scope, sort, map) {
  const hasMore = rows.length > limit;
  const items = rows.slice(0, limit).map(map);
  const tail = rows[limit - 1];
  const nextCursor = hasMore ? encodeCursor({
    scope, actor: actor.id, snapshot,
    createdAt: tail.cursor_created_at, id: tail.id,
    ...(sort.startsWith('amount') ? { amount: tail.amount } : {}),
  }, secret) : null;
  return { items, next_cursor: nextCursor };
}

function packPage(rows, limit, snapshot, secret, actor, scope, map) {
  const hasMore = rows.length > limit;
  const items = rows.slice(0, limit).map(map);
  const tail = rows[limit - 1];
  const nextCursor = hasMore ? encodeCursor({
    scope, actor: actor.id, snapshot,
    createdAt: tail.cursor_created_at, id: tail.id,
  }, secret) : null;
  return { items, next_cursor: nextCursor };
}

export async function listMerchantContacts(pool, secret, actor, { limit, cursor, q }) {
  const count = page(limit);
  const term = searchTerm(q);
  const scope = scopeFor('merchant_contacts', { term });
  const parsed = cursorFor(cursor, secret, actor, scope);
  const snapshot = parsed?.snapshot ?? (await pool.query('SELECT clock_timestamp()::text AS captured_at')).rows[0].captured_at;
  const { rows } = await pool.query(`
    SELECT id,display_name AS name,normalized_phone AS phone,created_at,
      created_at::text AS cursor_created_at
    FROM merchant_contacts
    WHERE merchant_id=$1 AND created_at <= $2::timestamptz
      AND ($3::timestamptz IS NULL OR (created_at,id)<($3::timestamptz,$4::uuid))
      AND ($6::text IS NULL OR position(lower($6) in lower(display_name))>0
        OR position($6 in normalized_phone)>0)
    ORDER BY created_at DESC,id DESC LIMIT $5`,
    [actor.id, snapshot, parsed?.createdAt ?? null, parsed?.id ?? null, count + 1, term]);
  return packPage(rows,count,snapshot,secret,actor,scope,row=>({
    contact_id:row.id, name:row.name, phone:row.phone, created_at:row.created_at,
  }));
}

export async function listMerchantContactClaims(pool, secret, actor, contactId, { limit, cursor, q, type, currency, from, to, sort }) {
  const id = uuid(contactId, 'contact_id');
  const count = page(limit);
  const term = searchTerm(q);
  const operationType = claimType(type);
  const unit = optionalCurrency(currency);
  const fromBound = dateBound(from, 'from');
  const toBound = dateBound(to, 'to', { endExclusive: true });
  if (fromBound && toBound && toBound <= fromBound) {
    throw new ApiError(422, 'invalid_input', 'to must not precede from');
  }
  const ordering = claimSort(sort);
  const scope = scopeFor(`merchant_contact_claims:${id}`, {
    term, type: operationType, currency: unit,
  }) + ':s:' + ordering + (fromBound ? ':f:' + fromBound : '') + (toBound ? ':t:' + toBound : '');
  const parsed = cursorFor(cursor, secret, actor, scope);
  const snapshot = parsed?.snapshot ?? (await pool.query('SELECT clock_timestamp()::text AS captured_at')).rows[0].captured_at;
  const contact = await pool.query(`SELECT 1 FROM merchant_contacts WHERE id=$1 AND merchant_id=$2`,
    [id, actor.id]);
  if (!contact.rowCount) throw new ApiError(404,'not_found','Not found');
  const amountOrder = ordering.startsWith('amount');
  if (amountOrder && parsed && typeof parsed.amount !== 'string') {
    throw new ApiError(422, 'invalid_input', 'Cursor is not valid for this sort');
  }
  const cursorA = amountOrder ? (parsed?.amount ?? null) : (parsed?.createdAt ?? null);
  const cursorType = amountOrder ? 'numeric' : 'timestamptz';
  const cursorDirection = ordering.endsWith('_asc') || ordering === 'oldest' ? '>' : '<';
  const orderBy = amountOrder
    ? `cl.amount ${ordering === 'amount_asc' ? 'ASC' : 'DESC'},cl.id ${ordering === 'amount_asc' ? 'ASC' : 'DESC'}`
    : `cl.created_at ${ordering === 'oldest' ? 'ASC' : 'DESC'},cl.id ${ordering === 'oldest' ? 'ASC' : 'DESC'}`;
  const { rows } = await pool.query(`
    SELECT cl.id,cl.contact_id,cl.amount::text,cl.currency,cl.operation_type AS type,cl.description,cl.created_at,
      cl.created_at::text AS cursor_created_at,
      d.decision, r.id AS relationship_id, r.status AS relationship_status, fm.id AS movement_id,
      cl.superseded_by_claim_id,
      EXISTS(SELECT 1 FROM financial_amendment_requests ar WHERE ar.original_claim_id=cl.id AND ar.status='pending') AS amendment_pending,
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
      AND ($4::${cursorType} IS NULL OR (${amountOrder ? 'cl.amount,cl.id' : 'cl.created_at,cl.id'})
        ${cursorDirection} ($4::${cursorType},$5::uuid))
      AND ($7::text IS NULL OR position(lower($7) in lower(coalesce(cl.description,'')))>0
        OR position($7 in cl.amount::text)>0)
      AND ($8::text IS NULL OR cl.operation_type=$8)
      AND ($9::text IS NULL OR cl.currency=$9)
      AND ($10::timestamptz IS NULL OR cl.created_at >= $10::timestamptz)
      AND ($11::timestamptz IS NULL OR cl.created_at < $11::timestamptz)
    ORDER BY ${orderBy} LIMIT $6`,
    [actor.id,id,snapshot,cursorA,parsed?.id ?? null,count + 1,term,operationType,unit,fromBound,toBound]);
  return packClaimPage(rows,count,snapshot,secret,actor,scope,ordering,row=>({
    claim_id:row.id,contact_id:row.contact_id,amount:row.amount,currency:row.currency,type:row.type,
    description:row.description,created_at:row.created_at,
    relationship_id:row.relationship_id,relationship_status:row.relationship_status,
    stage: row.superseded_by_claim_id ? 'superseded' :
      row.amendment_pending ? 'amendment_pending' :
      row.movement_id ? 'approved' :
      row.decision==='reject' ? 'rejected' :
      !row.verified ? 'outside_app' :
      row.decision==='accept' && row.relationship_status==='approved' ? 'accepted_awaiting_posting' :
      row.decision==='accept' ? 'accepted_awaiting_relationship' : 'awaiting_review',
  }));
}