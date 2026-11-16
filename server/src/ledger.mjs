import { createHash, randomUUID } from 'node:crypto';
import { ApiError, assertText, currency, decodeCursor, encodeCursor, idempotencyKey, money, page, uuid } from './validation.mjs';
import { fromTenThousandths, ledgerSigned, toTenThousandths } from './decimal.mjs';

const missing=()=>new ApiError(404,'not_found','Account or operation not found');
const conflict=message=>new ApiError(409,'conflict',message);
const validType=value=>{
  if(value!=='debt' && value!=='payment') throw new ApiError(422,'invalid_input','Type must be debt or payment');
  return value;
};
const digest=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
function occurredAt(value) {
  if(value==null) return null;
  if(typeof value!=='string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) {
    throw new ApiError(422,'invalid_input','occurred_at must have an explicit time zone');
  }
  const ms=Date.parse(value);
  if(!Number.isFinite(ms) || ms<Date.UTC(2000,0,1) || ms>Date.now()+86400000) {
    throw new ApiError(422,'invalid_input','occurred_at outside permitted range');
  }
  return new Date(ms).toISOString();
}
function statementPeriod(from,to) {
  if(typeof from!=='string'||typeof to!=='string'||
      !/^\d{4}-\d{2}-\d{2}$/.test(from)||!/^\d{4}-\d{2}-\d{2}$/.test(to)) {
    throw new ApiError(422,'invalid_input','Use from/to in YYYY-MM-DD format');
  }
  const a=Date.parse(from+'T00:00:00Z'),b=Date.parse(to+'T00:00:00Z');
  if(!Number.isFinite(a)||!Number.isFinite(b)||
      new Date(a).toISOString().slice(0,10)!==from||
      new Date(b).toISOString().slice(0,10)!==to||
      b<a || b-a>366*86400000) {
    throw new ApiError(422,'invalid_input','Invalid statement period (maximum 367 days inclusive)');
  }
}

// FIN-13 extends the EXISTING financial_movements approved ledger. Pending
// operations are not posted, and historic merchant claims use that same ledger.
export class FinancialLedgerService {
  constructor(store){this.store=store;}

  async relationship(c,actor,relationshipId,{lock=false,write=false}={}) {
    const id=uuid(relationshipId,'relationship_id');
    const first=await c.query('SELECT merchant_id,customer_id FROM merchant_relationships WHERE id=$1',[id]);
    if(!first.rowCount) throw missing();
    const pair=first.rows[0];
    if(actor.role==='merchant' ? pair.merchant_id!==actor.id :
      actor.role==='customer' ? pair.customer_id!==actor.id : true) throw missing();
    if(lock) await this.store.lockRelationshipPair(c,pair.merchant_id,pair.customer_id);
    const q=await c.query('SELECT * FROM merchant_relationships WHERE id=$1'+(lock?' FOR UPDATE':''),[id]);
    if(!q.rowCount) throw missing();
    const rel=q.rows[0];
    if(actor.role==='customer'||write) {
      const contact=await c.query('SELECT normalized_phone FROM merchant_contacts WHERE id=$1 AND merchant_id=$2',
        [rel.contact_id,rel.merchant_id]);
      if(!contact.rowCount) throw missing();
      if(write) await this.store.lockPhone(c,contact.rows[0].normalized_phone);
      const verified=await c.query([
        'SELECT 1 FROM verified_contact_links vl',
        'JOIN customer_phone_evidence ev ON ev.proof_reference=vl.proof_reference',
        'AND ev.customer_id=vl.customer_id AND ev.revoked_at IS NULL',
        'WHERE vl.merchant_id=$1 AND vl.contact_id=$2 AND vl.customer_id=$3',
        'AND ev.normalized_phone=$4',
        'AND (SELECT COUNT(DISTINCT e.customer_id) FROM customer_phone_evidence e',
        'WHERE e.normalized_phone=$4 AND e.revoked_at IS NULL)=1'
      ].join(' '),[rel.merchant_id,rel.contact_id,rel.customer_id,contact.rows[0].normalized_phone]);
      if(!verified.rowCount) throw missing();
    }
    return rel;
  }

  async postOperation(c,operationId,actorId) {
    const {rows}=await c.query([
      'INSERT INTO financial_movements',
      '(id,source_operation_id,relationship_id,merchant_id,customer_id,amount,currency,type,reversal_of_movement_id)',
      'SELECT $2,o.id,o.relationship_id,o.merchant_id,o.customer_id,o.amount,o.currency,',
      'o.operation_type,o.reversal_of_movement_id FROM relationship_operations o',
      'JOIN merchant_relationships r ON r.id=o.relationship_id AND r.status=\'approved\'',
      'WHERE o.id=$1 AND o.status=\'approved\'',
      'ON CONFLICT (source_operation_id) DO NOTHING RETURNING id'
    ].join(' ').replaceAll("\'","'"),[operationId,randomUUID()]);
    if(rows.length) await this.store.audit(c,actorId,'operation',operationId,'posted_once_to_approved_ledger');
    return rows.length>0;
  }

  async activeAllocationAmount(c,movementId) {
    const q=await c.query([
      'SELECT COALESCE(SUM(CASE WHEN action=\\'allocate\\' THEN amount ELSE -amount END),0)::text AS amount',
      'FROM financial_payment_allocation_entries',
      'WHERE payment_movement_id=$1 OR debt_movement_id=$1'
    ].join(' '),[movementId]);
    return toTenThousandths(q.rows[0].amount);
  }

  async createOperation(actor,relationshipId,body,key) {
    const id=uuid(relationshipId,'relationship_id');
    const amount=money(body.amount);
    const unit=currency(body.currency);
    const type=validType(body.type);
    const description=body.description==null?null:assertText(body.description,'description',500);
    const date=occurredAt(body.occurred_at);
    const idempotency=idempotencyKey(key);
    const requestDigest=digest([id,type,amount,unit,description,date]);
    if(type==='debt' && actor.role!=='merchant') {
      throw new ApiError(403,'forbidden','Only merchants create debt requests');
    }
    return this.store.tx(async c=>{
      const rel=await this.relationship(c,actor,id,{lock:true,write:true});
      const prior=await c.query('SELECT o.id,o.status,o.request_digest,fm.id AS movement_id FROM relationship_operations o LEFT JOIN financial_movements fm ON fm.source_operation_id=o.id WHERE o.created_by=$1 AND o.idempotency_key=$2',
        [actor.id,idempotency]);
      if(prior.rowCount){
        if(prior.rows[0].request_digest!==requestDigest) throw conflict('Idempotency-Key reused with different operation');
        return {operation_id:prior.rows[0].id,status:prior.rows[0].status,replayed:true,ledger_posted:prior.rows[0].movement_id!=null};
      }
      if(rel.status!=='approved') throw conflict('An approved relationship is required');
      const creditWarning=type==='debt'
        ?await this.store.credit.evaluateNewDebt(c,id,unit,amount):null;
      const policy=await c.query('SELECT enabled,version FROM relationship_auto_approval_policies WHERE relationship_id=$1',
        [id]);
      const auto=type==='debt' && actor.role==='merchant' && policy.rows[0]?.enabled===true;
      const oid=randomUUID();
      await c.query([
        'INSERT INTO relationship_operations',
        '(id,relationship_id,merchant_id,customer_id,created_by,created_by_role,',
        'operation_type,amount,currency,description,occurred_at,created_at,status,',
        'decided_at,decided_by,approval_method,auto_policy_version,idempotency_key,request_digest)',
        'VALUES($1,$2,$3,$4,$5,$6,$7,$8::numeric,$9,$10,COALESCE($11::timestamptz,clock_timestamp()),',
        'clock_timestamp(),$12,CASE WHEN $13 THEN clock_timestamp() ELSE NULL END,',
        'CASE WHEN $13 THEN $4 ELSE NULL END,$14,$15,$16,$17)'
      ].join(' '),[oid,id,rel.merchant_id,rel.customer_id,actor.id,actor.role,
        type,amount,unit,description,date,auto?'approved':'pending',auto,
        auto?'delegated_policy':'manual',auto?policy.rows[0].version:null,
        idempotency,requestDigest]);
      await this.store.audit(c,actor.id,'operation',oid,
        auto?'created_with_valid_customer_delegation':'created_pending_other_party',
        {type,currency:unit,relationship_id:id,auto_policy_version:auto?policy.rows[0].version:null});
      const posted=auto?await this.postOperation(c,oid,actor.id):false;
      return {operation_id:oid,status:auto?'approved':'pending',
        approval_method:auto?'delegated_policy':'manual',
        auto_policy_version:auto?policy.rows[0].version:null,
        ledger_posted:posted,replayed:false,credit_warning:creditWarning};
    });
  }

  async decideOperation(actor,relationshipId,operationId,body) {
    const relId=uuid(relationshipId,'relationship_id');
    const opId=uuid(operationId,'operation_id');
    if(body.decision!=='accept'&&body.decision!=='reject') {
      throw new ApiError(422,'invalid_input','decision must be accept or reject');
    }
    return this.store.tx(async c=>{
      const rel=await this.relationship(c,actor,relId,{lock:true,write:true});
      const q=await c.query('SELECT * FROM relationship_operations WHERE id=$1 AND relationship_id=$2 FOR UPDATE',
        [opId,relId]);
      if(!q.rowCount) throw missing();
      const op=q.rows[0];
      if(op.created_by===actor.id || op.created_by_role===actor.role) {
        throw new ApiError(403,'forbidden','Only the other participant can decide');
      }
      const target=body.decision==='accept'?'approved':'rejected';
      if(op.status!=='pending') {
        if(op.status!==target || op.approval_method!=='manual') throw conflict('Operation already decided');
        return {operation_id:opId,status:target,replayed:true,ledger_posted:false};
      }
      if(rel.status!=='approved') throw conflict('Relationship is not approved');
      if(target==='approved' && op.reversal_of_movement_id &&
         await this.activeAllocationAmount(c,op.reversal_of_movement_id)>0n) {
        throw conflict('Release approved payment allocations before reversing this movement');
      }
      const amendment=await c.query('SELECT 1 FROM financial_amendment_requests WHERE original_operation_id=$1 AND status=$2',[opId,'pending']);
      if(amendment.rowCount) throw conflict('Amount amendment awaits merchant response');
      await c.query('UPDATE relationship_operations SET status=$2,decided_at=clock_timestamp(),decided_by=$3 WHERE id=$1',
        [opId,target,actor.id]);
      await this.store.audit(c,actor.id,'operation',opId,
        target==='approved'?'other_party_approved':'other_party_rejected');
      const posted=target==='approved'?await this.postOperation(c,opId,actor.id):false;
      return {operation_id:opId,status:target,replayed:false,ledger_posted:posted};
    });
  }

  async setAutoApproval(actor,relationshipId,body) {
    if(actor.role!=='customer') throw new ApiError(403,'forbidden','Customer authorization required');
    if(typeof body.enabled!=='boolean') throw new ApiError(422,'invalid_input','enabled must be boolean');
    const id=uuid(relationshipId,'relationship_id');
    return this.store.tx(async c=>{
      const rel=await this.relationship(c,actor,id,{lock:true,write:true});
      if(rel.status!=='approved') throw conflict('An approved relationship is required');
      const existing=await c.query('SELECT * FROM relationship_auto_approval_policies WHERE relationship_id=$1',[id]);
      if(existing.rows[0]?.enabled===body.enabled){
        return {relationship_id:id,enabled:body.enabled,version:existing.rows[0].version,replayed:true};
      }
      const q=await c.query([
        'INSERT INTO relationship_auto_approval_policies',
        '(relationship_id,enabled,version,effective_at,disabled_at,updated_by,updated_at)',
        'VALUES($1,$2,1,CASE WHEN $2 THEN clock_timestamp() ELSE NULL END,',
        'CASE WHEN $2 THEN NULL ELSE clock_timestamp() END,$3,clock_timestamp())',
        'ON CONFLICT (relationship_id) DO UPDATE SET',
        'enabled=EXCLUDED.enabled,version=relationship_auto_approval_policies.version+1,',
        'effective_at=CASE WHEN $2 THEN clock_timestamp() ELSE relationship_auto_approval_policies.effective_at END,',
        'disabled_at=CASE WHEN $2 THEN NULL ELSE clock_timestamp() END,',
        'updated_by=$3,updated_at=clock_timestamp() RETURNING version,enabled,effective_at,disabled_at'
      ].join(' '),[id,body.enabled,actor.id]);
      const row=q.rows[0];
      await c.query('INSERT INTO relationship_policy_events(id,relationship_id,version,enabled,actor_id) VALUES($1,$2,$3,$4,$5)',
        [randomUUID(),id,row.version,row.enabled,actor.id]);
      await this.store.audit(c,actor.id,'relationship',id,body.enabled?
        'customer_enabled_future_debt_auto_approval':'customer_disabled_future_debt_auto_approval',
        {version:row.version});
      return {relationship_id:id,enabled:row.enabled,version:row.version,
        effective_at:row.effective_at,disabled_at:row.disabled_at,replayed:false};
    });
  }

  async getAutoApproval(actor,relationshipId) {
    const id=uuid(relationshipId,'relationship_id');
    return this.store.tx(async c=>{
      await this.relationship(c,actor,id);
      const q=await c.query('SELECT enabled,version,effective_at,disabled_at FROM relationship_auto_approval_policies WHERE relationship_id=$1',[id]);
      return {relationship_id:id,enabled:q.rows[0]?.enabled??false,
        version:q.rows[0]?.version??0,
        effective_at:q.rows[0]?.effective_at??null,
        disabled_at:q.rows[0]?.disabled_at??null};
    });
  }

  async requestReversal(actor,relationshipId,body,key) {
    const relId=uuid(relationshipId,'relationship_id');
    const movementId=uuid(body.movement_id,'movement_id');
    const reason=assertText(body.reason,'reason',500);
    const idempotency=idempotencyKey(key);
    const requestDigest=digest([relId,'reversal',movementId,reason]);
    return this.store.tx(async c=>{
      const rel=await this.relationship(c,actor,relId,{lock:true,write:true});
      const prior=await c.query('SELECT o.id,o.status,o.request_digest,fm.id AS movement_id FROM relationship_operations o LEFT JOIN financial_movements fm ON fm.source_operation_id=o.id WHERE o.created_by=$1 AND o.idempotency_key=$2',
        [actor.id,idempotency]);
      if(prior.rowCount){
        if(prior.rows[0].request_digest!==requestDigest) throw conflict('Idempotency-Key reused with different reversal');
        return {operation_id:prior.rows[0].id,status:prior.rows[0].status,replayed:true};
      }
      if(rel.status!=='approved') throw conflict('An approved relationship is required');
      const original=await c.query('SELECT id,amount::text,currency,type FROM financial_movements WHERE id=$1 AND relationship_id=$2',
        [movementId,relId]);
      if(!original.rowCount) throw missing();
      const existing=await c.query([
        'SELECT 1 FROM relationship_operations WHERE reversal_of_movement_id=$1 AND status<>\'rejected\'',
        'UNION ALL SELECT 1 FROM financial_movements WHERE reversal_of_movement_id=$1 LIMIT 1'
      ].join(' ').replaceAll("\'","'"),[movementId]);
      if(existing.rowCount) throw conflict('A reversal already exists or is awaiting approval');
      if(await this.activeAllocationAmount(c,movementId)>0n) {
        throw conflict('Release approved payment allocations before requesting a reversal');
      }
      const source=original.rows[0],id=randomUUID();
      const opposite=source.type==='debt'?'payment':'debt';
      await c.query([
        'INSERT INTO relationship_operations',
        '(id,relationship_id,merchant_id,customer_id,created_by,created_by_role,',
        'operation_type,amount,currency,description,reversal_of_movement_id,idempotency_key,request_digest)',
        'VALUES($1,$2,$3,$4,$5,$6,$7,$8::numeric,$9,$10,$11,$12,$13)'
      ].join(' '),[id,relId,rel.merchant_id,rel.customer_id,actor.id,actor.role,opposite,
        source.amount,source.currency,reason,movementId,idempotency,requestDigest]);
      await this.store.audit(c,actor.id,'operation',id,'reversal_requested_pending_other_party',
        {original_movement_id:movementId});
      return {operation_id:id,status:'pending',replayed:false};
    });
  }

  async balances(actor,relationshipId) {
    const id=uuid(relationshipId,'relationship_id');
    return this.store.tx(async c=>{
      await this.relationship(c,actor,id);
      const {rows}=await c.query([
        'SELECT currency,',
        'COALESCE(SUM(CASE WHEN type=\'debt\' THEN amount ELSE 0 END),0)::text AS approved_debts,',
        'COALESCE(SUM(CASE WHEN type=\'payment\' THEN amount ELSE 0 END),0)::text AS approved_payments,',
        'COALESCE(SUM(CASE WHEN type=\'debt\' THEN amount ELSE -amount END),0)::text AS balance',
        'FROM financial_movements WHERE relationship_id=$1 GROUP BY currency ORDER BY currency'
      ].join(' ').replaceAll("\'","'"),[id]);
      const map=new Map(rows.map(x=>[x.currency,x]));
      return {relationship_id:id,currencies:['YER','SAR','USD'].map(unit=>({
        currency:unit,approved_debts:map.get(unit)?.approved_debts??'0.0000',
        approved_payments:map.get(unit)?.approved_payments??'0.0000',
        balance:map.get(unit)?.balance??'0.0000'})),
        scope:'approved_ledger_only'};
    });
  }

  async statement(actor,relationshipId,{currency:unit,from,to}) {
    const id=uuid(relationshipId,'relationship_id');
    const code=currency(unit);
    statementPeriod(from,to);
    return this.store.tx(async c=>{
      await c.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY');
      await this.relationship(c,actor,id);
      const opening=await c.query([
        'SELECT COALESCE(SUM(CASE WHEN type=\'debt\' THEN amount ELSE -amount END),0)::text AS balance',
        'FROM financial_movements WHERE relationship_id=$1 AND currency=$2',
        'AND (posted_at AT TIME ZONE \\u0027Asia/Aden\\u0027)::date<$3::date'
      ].join(' ').replaceAll("\'","'").replaceAll("\\u0027","'"),[id,code,from]);
      const q=await c.query([
        'SELECT id,amount::text,currency,type,posted_at,reversal_of_movement_id,',
        'source_claim_id,source_operation_id',
        'FROM financial_movements WHERE relationship_id=$1 AND currency=$2',
        'AND (posted_at AT TIME ZONE \\u0027Asia/Aden\\u0027)::date BETWEEN $3::date AND $4::date',
        'ORDER BY posted_at,id LIMIT 501'
      ].join(' ').replaceAll("\\u0027","'"),[id,code,from,to]);
      if(q.rows.length>500) throw new ApiError(413,'statement_too_large',
        'Statement contains more than 500 entries; use a narrower date period');
      let debts=0n,payments=0n;
      for(const row of q.rows){
        if(row.type==='debt') debts+=toTenThousandths(row.amount);
        else payments+=toTenThousandths(row.amount);
      }
      const open=toTenThousandths(opening.rows[0].balance);
      return {relationship_id:id,currency:code,from,to,time_zone:'Asia/Aden',
        opening_balance:fromTenThousandths(open),
        approved_debts:fromTenThousandths(debts),
        approved_payments:fromTenThousandths(payments),
        closing_balance:fromTenThousandths(open+debts-payments),
        items:q.rows.map(x=>({
          movement_id:x.id,amount:x.amount,currency:x.currency,type:x.type,
          posted_at:x.posted_at,reversal_of_movement_id:x.reversal_of_movement_id,
          source_claim_id:x.source_claim_id,source_operation_id:x.source_operation_id
        })),
        scope:'approved_ledger_only'};
    });
  }

  async operations(actor,relationshipId,{limit,cursor}) {
    const id=uuid(relationshipId,'relationship_id');
    const count=page(limit);
    const decoded=decodeCursor(cursor,this.store.cursorSecret);
    const scope='relationship_operations:'+id;
    if(decoded && (decoded.scope!==scope || decoded.actor!==actor.id)) {
      throw new ApiError(422,'invalid_input','Cursor belongs to another account or relationship');
    }
    return this.store.tx(async c=>{
      await this.relationship(c,actor,id);
      const snap=decoded?.snapshot??(await c.query('SELECT clock_timestamp()::text AS t')).rows[0].t;
      const q=await c.query([
        'SELECT id,operation_type,amount::text,currency,description,occurred_at,created_at,',
        'created_at::text AS cursor_created_at,created_by,created_by_role,status,decided_at,',
        'decided_by,approval_method,auto_policy_version,reversal_of_movement_id,replaces_operation_id,',
        '(SELECT EXISTS(SELECT 1 FROM financial_amendment_requests a',
        'WHERE a.original_operation_id=relationship_operations.id AND a.status=\'pending\')) AS amendment_pending',
        'FROM relationship_operations WHERE relationship_id=$1 AND created_at<=$2::timestamptz',
        'AND ($3::timestamptz IS NULL OR (created_at,id)<($3::timestamptz,$4::uuid))',
        'ORDER BY created_at DESC,id DESC LIMIT $5'
      ].join(' '),[id,snap,decoded?.createdAt??null,decoded?.id??null,count+1]);
      const more=q.rows.length>count;
      const items=q.rows.slice(0,count).map(({cursor_created_at,...rest})=>rest);
      const tail=q.rows[count-1];
      return {items,next_cursor:more?encodeCursor({scope,actor:actor.id,snapshot:snap,
        createdAt:tail.cursor_created_at,id:tail.id},this.store.cursorSecret):null};
    });
  }
}
