import { createHash, randomUUID } from 'node:crypto';
import { ApiError, assertText, claimDigest, decodeCursor, encodeCursor, idempotencyKey, money, page, uuid } from './validation.mjs';
import { toTenThousandths } from './decimal.mjs';

const missing=()=>new ApiError(404,'not_found','Amendment or source operation not found');
const conflict=(message)=>new ApiError(409,'conflict',message);
const hash=(fields)=>createHash('sha256').update(JSON.stringify(fields)).digest('hex');

function validateProposal(amount,reason){
  return {amount:money(amount),reason:assertText(reason,'reason',500)};
}
function changed(oldAmount,newAmount){
  if(toTenThousandths(oldAmount)===toTenThousandths(newAmount)){
    throw new ApiError(422,'invalid_input','Proposed amount must be different from original amount');
  }
}
function receipt(row,{replayed=false,ledgerPosted=false}={}){
  return {
    amendment_id:row.id,status:row.status,
    original_claim_id:row.original_claim_id??null,
    original_operation_id:row.original_operation_id??null,
    original_amount:row.original_amount,
    proposed_amount:row.proposed_amount,
    currency:row.currency,
    reason:row.reason,customer_name:row.customer_name??null,
    replacement_claim_id:row.replacement_claim_id??null,
    replacement_operation_id:row.replacement_operation_id??null,
    recorded_at:row.requested_at,decided_at:row.decided_at??null,
    replayed,ledger_posted:ledgerPosted
  };
}

/**
 * Financial amendment: customer proposes a new exact amount, merchant agrees
 * or rejects. Original amount and approved postings are NEVER overwritten.
 * Same pair advisory lock is used by FIN-08/13/14 to avoid parallel consent.
 */
export class Fin15AmendmentService {
  constructor(store){this.store=store;}

  async _priorByKey(c,actor,key,digest){
    const q=await c.query('SELECT *,original_amount::text AS old_money,proposed_amount::text AS new_money FROM financial_amendment_requests WHERE customer_id=$1 AND request_key=$2',
      [actor.id,key]);
    if(!q.rowCount)return null;
    if(q.rows[0].request_digest!==digest)throw conflict('Idempotency-Key reused for another amendment');
    const row=q.rows[0];
    return receipt({...row,original_amount:row.old_money,proposed_amount:row.new_money},{replayed:true});
  }

  async _assertFreeClaim(c,id) {
    const q=await c.query([
      'SELECT 1 FROM customer_claim_decisions WHERE claim_id=$1',
      'UNION ALL SELECT 1 FROM financial_movements WHERE source_claim_id=$1',
      'UNION ALL SELECT 1 FROM financial_amendment_requests',
      'WHERE original_claim_id=$1 AND status=\'pending\' LIMIT 1'
    ].join(' ').replaceAll("\'","'"),[id]);
    if(q.rowCount)throw conflict('Claim was decided, posted or is being amended');
  }

  async requestHistorical(actor,claimId,body,key) {
    if(actor.role!=='customer')throw new ApiError(403,'forbidden','Customer role required');
    const originalId=uuid(claimId,'claim_id');
    const proposed=validateProposal(body.proposed_amount,body.reason);
    const requestKey=idempotencyKey(key);
    const requestDigest=hash(['historical',originalId,proposed.amount,proposed.reason]);
    return this.store.tx(async c=>{
      const pair=await c.query('SELECT merchant_id FROM merchant_claims WHERE id=$1',[originalId]);
      if(!pair.rowCount)throw missing();
      await this.store.lockRelationshipPair(c,pair.rows[0].merchant_id,actor.id);
      const eligible=await this.store.ensureEligible(c,originalId,actor.id,{allowAmendment:true});
      const prior=await this._priorByKey(c,actor,requestKey,requestDigest);
      if(prior)return prior;
      const q=await c.query([
        'SELECT amount::text,operation_type,currency,superseded_by_claim_id',
        'FROM merchant_claims WHERE id=$1'
      ].join(' '),[originalId]);
      const row=q.rows[0];
      if(row.operation_type!=='debt')throw new ApiError(422,'invalid_input','Only debt amounts can be amended');
      if(row.superseded_by_claim_id)throw conflict('Original claim was superseded');
      changed(row.amount,proposed.amount);
      await this._assertFreeClaim(c,originalId);
      const id=randomUUID();
      const inserted=await c.query([
        'INSERT INTO financial_amendment_requests',
        '(id,original_claim_id,merchant_id,customer_id,original_amount,proposed_amount,currency,reason,request_key,request_digest)',
        'VALUES($1,$2,$3,$4,$5::numeric,$6::numeric,$7,$8,$9,$10)',
        'RETURNING *,original_amount::text AS old_money,proposed_amount::text AS new_money'
      ].join(' '),[id,originalId,eligible.merchant_id,actor.id,
        row.amount,proposed.amount,row.currency,proposed.reason,requestKey,requestDigest]);
      const saved=inserted.rows[0];
      await this.store.audit(c,actor.id,'financial_amendment',id,'customer_proposed_historical_debt_change',
        {claim_id:originalId,currency:row.currency,old_amount:row.amount,proposed_amount:proposed.amount});
      return receipt({...saved,original_amount:saved.old_money,proposed_amount:saved.new_money});
    });
  }

  async requestOperation(actor,relationshipId,operationId,body,key){
    if(actor.role!=='customer')throw new ApiError(403,'forbidden','Customer role required');
    const relId=uuid(relationshipId,'relationship_id');
    const sourceId=uuid(operationId,'operation_id');
    const proposed=validateProposal(body.proposed_amount,body.reason);
    const requestKey=idempotencyKey(key);
    const requestDigest=hash(['operation',relId,sourceId,proposed.amount,proposed.reason]);
    return this.store.tx(async c=>{
      const rel=await this.store.ledger.relationship(c,actor,relId,{lock:true,write:true});
      if(rel.status!=='approved')throw conflict('Relationship not approved');
      const q=await c.query([
        'SELECT amount::text,operation_type,status,currency,created_by_role',
        'FROM relationship_operations WHERE id=$1 AND relationship_id=$2 FOR UPDATE'
      ].join(' '),[sourceId,relId]);
      if(!q.rowCount)throw missing();
      const row=q.rows[0];
      const prior=await this._priorByKey(c,actor,requestKey,requestDigest);
      if(prior)return prior;
      if(row.status!=='pending'||row.operation_type!=='debt'||row.created_by_role!=='merchant') {
        throw conflict('Only pending merchant-created debt can be amended');
      }
      changed(row.amount,proposed.amount);
      const pending=await c.query('SELECT 1 FROM financial_amendment_requests WHERE original_operation_id=$1 AND status=$2',
        [sourceId,'pending']);
      if(pending.rowCount)throw conflict('An amendment is already awaiting merchant response');
      const id=randomUUID();
      const inserted=await c.query([
        'INSERT INTO financial_amendment_requests',
        '(id,original_operation_id,merchant_id,customer_id,original_amount,proposed_amount,currency,reason,request_key,request_digest)',
        'VALUES($1,$2,$3,$4,$5::numeric,$6::numeric,$7,$8,$9,$10)',
        'RETURNING *,original_amount::text AS old_money,proposed_amount::text AS new_money'
      ].join(' '),[id,sourceId,rel.merchant_id,actor.id,row.amount,
        proposed.amount,row.currency,proposed.reason,requestKey,requestDigest]);
      const saved=inserted.rows[0];
      await this.store.audit(c,actor.id,'financial_amendment',id,'customer_proposed_pending_debt_change',
        {operation_id:sourceId,currency:row.currency,old_amount:row.amount,proposed_amount:proposed.amount});
      return receipt({...saved,original_amount:saved.old_money,proposed_amount:saved.new_money});
    });
  }

  async decideMerchant(actor,amendmentId,body){
    if(actor.role!=='merchant')throw new ApiError(403,'forbidden','Merchant role required');
    const id=uuid(amendmentId,'amendment_id');
    if(body.decision!=='accept'&&body.decision!=='reject'){
      throw new ApiError(422,'invalid_input','decision must be accept or reject');
    }
    return this.store.tx(async c=>{
      // Only identifiers are read before locks. Private content must not be
      // disclosed to any other merchant or caller.
      const look=await c.query([
        'SELECT merchant_id,customer_id,original_claim_id,original_operation_id',
        'FROM financial_amendment_requests WHERE id=$1'
      ].join(' '),[id]);
      if(!look.rowCount||look.rows[0].merchant_id!==actor.id)throw missing();
      const meta=look.rows[0];
      await this.store.lockRelationshipPair(c,meta.merchant_id,meta.customer_id);
      let original;
      if(meta.original_claim_id){
        await this.store.ensureEligible(c,meta.original_claim_id,meta.customer_id,{allowAmendment:true});
        const source=await c.query('SELECT * FROM merchant_claims WHERE id=$1 FOR UPDATE',[meta.original_claim_id]);
        original=source.rows[0];
      }else{
        const relQuery=await c.query('SELECT relationship_id FROM relationship_operations WHERE id=$1',
          [meta.original_operation_id]);
        if(!relQuery.rowCount)throw missing();
        await this.store.ledger.relationship(c,actor,relQuery.rows[0].relationship_id,
          {lock:false,write:true});
        const source=await c.query('SELECT * FROM relationship_operations WHERE id=$1 FOR UPDATE',
          [meta.original_operation_id]);
        original=source.rows[0];
      }
      const q=await c.query('SELECT *,original_amount::text AS old_money,proposed_amount::text AS new_money FROM financial_amendment_requests WHERE id=$1 FOR UPDATE',[id]);
      if(!q.rowCount)throw missing();
      const amendment=q.rows[0];
      if(amendment.merchant_id!==actor.id)throw missing();
      const target=body.decision==='accept'?'accepted':'rejected';
      if(amendment.status!=='pending'){
        if(amendment.status!==target)throw conflict('Amendment already has another decision');
        return receipt({...amendment,original_amount:amendment.old_money,
          proposed_amount:amendment.new_money},{replayed:true,ledgerPosted:false});
      }
      if(meta.original_claim_id){
        if(original.superseded_by_claim_id ||
           original.operation_type!=='debt')throw conflict('Historic claim is no longer amendable');
        const decisions=await c.query('SELECT 1 FROM customer_claim_decisions WHERE claim_id=$1',
          [original.id]);
        if(decisions.rowCount)throw conflict('Historic claim already decided');
      }else if(original.status!=='pending' ||
              original.created_by_role!=='merchant'||original.operation_type!=='debt'){
        throw conflict('Operation already decided or cannot be amended');
      }
      if(target==='rejected'){
        const rejected=await c.query([
          'UPDATE financial_amendment_requests SET status=$2,decided_at=clock_timestamp(),',
          'decided_by=$3 WHERE id=$1 RETURNING *,original_amount::text AS old_money,',
          'proposed_amount::text AS new_money'
        ].join(' '),[id,'rejected',actor.id]);
        await this.store.audit(c,actor.id,'financial_amendment',id,'merchant_rejected_amount_proposal');
        const row=rejected.rows[0];
        return receipt({...row,original_amount:row.old_money,proposed_amount:row.new_money});
      }
      let claimId=null,operationId=null,posted=false;
      if(meta.original_claim_id){
        claimId=randomUUID();
        const amount=amendment.new_money;
        const digest=claimDigest({
          contactId:original.contact_id,amount,currency:original.currency,
          description:original.description,type:'debt'});
        await c.query([
          'INSERT INTO merchant_claims(id,merchant_id,contact_id,amount,currency,',
          'description,operation_type,occurred_at,idempotency_key,request_digest)',
          'VALUES($1,$2,$3,$4::numeric,$5,$6,$7,$8,$9,$10)'
        ].join(' '),[claimId,original.merchant_id,original.contact_id,amount,
          original.currency,original.description,'debt',original.occurred_at,
          'fin15-amend-'+id,digest]);
        await c.query('UPDATE merchant_claims SET superseded_by_claim_id=$2 WHERE id=$1',
          [original.id,claimId]);
        await c.query([
          'INSERT INTO customer_claim_decisions(claim_id,merchant_id,customer_id,decision)',
          'VALUES($1,$2,$3,\'accept\')'
        ].join(' ').replaceAll("\'","'"),[claimId,original.merchant_id,amendment.customer_id]);
        await this.store.audit(c,amendment.customer_id,'merchant_claim',claimId,
          'customer_consented_by_amount_amendment_request',{amendment_id:id});
      }else{
        operationId=randomUUID();
        const digest=hash(['fin15 replacement',id,meta.original_operation_id,amendment.new_money]);
        await c.query([
          'UPDATE relationship_operations SET status=\'superseded\' WHERE id=$1'
        ].join(' ').replaceAll("\'","'"),[original.id]);
        await c.query([
          'INSERT INTO relationship_operations',
          '(id,relationship_id,merchant_id,customer_id,created_by,created_by_role,',
          'operation_type,amount,currency,description,occurred_at,status,',
          'decided_by,decided_at,approval_method,idempotency_key,request_digest,replaces_operation_id)',
          'VALUES($1,$2,$3,$4,$5,\'merchant\',\'debt\',$6::numeric,$7,$8,$9,',
          '\'approved\',$4,clock_timestamp(),\'manual\',$10,$11,$12)'
        ].join(' ').replaceAll("\'","'"),[
          operationId,original.relationship_id,original.merchant_id,
          original.customer_id,original.created_by,amendment.new_money,
          original.currency,original.description,original.occurred_at,
          'fin15-amend-'+id,digest,original.id
        ]);
        await this.store.audit(c,amendment.customer_id,'operation',operationId,
          'customer_consented_by_amount_amendment_request',{amendment_id:id});
      }
      const updated=await c.query([
        'UPDATE financial_amendment_requests SET status=\'accepted\',decided_at=clock_timestamp(),',
        'decided_by=$2,replacement_claim_id=$3,replacement_operation_id=$4 WHERE id=$1',
        'RETURNING *,original_amount::text AS old_money,proposed_amount::text AS new_money'
      ].join(' ').replaceAll("\'","'"),[id,actor.id,claimId,operationId]);
      await this.store.audit(c,actor.id,'financial_amendment',id,
        'merchant_accepted_customer_amount_proposal',{replacement_claim_id:claimId,
          replacement_operation_id:operationId});
      if(claimId)posted=await this.store.postClaim(c,claimId,actor.id);
      else posted=await this.store.ledger.postOperation(c,operationId,actor.id);
      const row=updated.rows[0];
      return receipt({...row,original_amount:row.old_money,proposed_amount:row.new_money},
        {ledgerPosted:posted});
    });
  }

  async list(actor,{limit,cursor}={}) {
    if(!['merchant','customer'].includes(actor.role))throw new ApiError(403,'forbidden','Participant role required');
    const count=page(limit);
    const scope='financial_amendments:'+actor.role;
    const parsed=decodeCursor(cursor,this.store.cursorSecret);
    if(parsed && (parsed.actor!==actor.id || parsed.scope!==scope)){
      throw new ApiError(422,'invalid_input','Invalid amendment list cursor');
    }
    return this.store.tx(async c=>{
      const snapshot=parsed?.snapshot??(await c.query('SELECT clock_timestamp()::text AS t')).rows[0].t;
      const property=actor.role==='merchant'?'a.merchant_id':'a.customer_id';
      // Column name comes from the server role enum, not user-supplied data.
      const q=await c.query([
        'SELECT a.*,a.original_amount::text AS old_money,a.proposed_amount::text AS new_money,',
        'a.requested_at::text AS cursor_date, c.display_name AS customer_name',
        'FROM financial_amendment_requests a',
        'LEFT JOIN merchant_claims historical ON historical.id=a.original_claim_id',
        'LEFT JOIN relationship_operations op ON op.id=a.original_operation_id',
        'LEFT JOIN merchant_relationships rel ON rel.id=op.relationship_id',
        'LEFT JOIN merchant_contacts c ON c.id=COALESCE(historical.contact_id,rel.contact_id)',
        'AND c.merchant_id=a.merchant_id',
        'WHERE '+property+'=$1 AND a.requested_at<=$2::timestamptz',
        'AND ($3::timestamptz IS NULL OR (a.requested_at,a.id)<($3::timestamptz,$4::uuid))',
        'ORDER BY a.requested_at DESC,a.id DESC LIMIT $5'
      ].join(' '),[actor.id,snapshot,parsed?.createdAt??null,parsed?.id??null,count+1]);
      const rows=q.rows.slice(0,count);
      const last=rows[rows.length-1];
      return {items:rows.map(row=>receipt({...row,original_amount:row.old_money,
        proposed_amount:row.new_money})),next_cursor:q.rows.length>count?
        encodeCursor({scope,actor:actor.id,snapshot,createdAt:last.cursor_date,id:last.id},
          this.store.cursorSecret):null};
    });
  }
}
