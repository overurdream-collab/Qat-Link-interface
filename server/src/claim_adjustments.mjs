import { randomUUID } from 'node:crypto';
import { ApiError, assertText, claimDigest, decision, money, uuid } from './validation.mjs';
import { toTenThousandths } from './decimal.mjs';

const conflict=message=>new ApiError(409,'conflict',message);
const missing=()=>new ApiError(404,'not_found','Adjustment or claim was not found');

/**
 * FIN-15: A customer can propose a different historical claim amount.
 * Approval creates a NEW pending merchant claim, linked to the original.
 * No adjustment modifies approved financial_movements or silently changes
 * the original merchant_claims.amount. The customer must approve the new claim.
 */
export class Fin15ClaimAdjustments {
  constructor(store){this.store=store;}

  async request(actor,claimId,body) {
    if(actor.role!=='customer')throw new ApiError(403,'forbidden','Customer role required');
    const id=uuid(claimId,'claim_id');
    const proposed=money(body.proposed_amount);
    const reason=assertText(body.reason,'reason',500);
    if(reason.length<2)throw new ApiError(422,'invalid_input','Explain why the amount should change');
    return this.store.tx(async c=>{
      const owner=await c.query('SELECT merchant_id FROM merchant_claims WHERE id=$1',[id]);
      if(!owner.rowCount)throw missing();
      await this.store.lockRelationshipPair(c,owner.rows[0].merchant_id,actor.id);
      const claim=await this.store.ensureEligible(c,id,actor.id,{allowAdjustment:true});
      if(toTenThousandths(money(claim.amount.toString()))===toTenThousandths(proposed)){
        throw new ApiError(422,'invalid_input','The proposed amount must be different');
      }
      const chosen=await c.query('SELECT decision FROM customer_claim_decisions WHERE claim_id=$1',[id]);
      if(chosen.rowCount)throw conflict('The customer already decided this financial claim');
      const existing=await c.query(
        "SELECT id,customer_id,proposed_amount::text,reason FROM customer_claim_adjustment_requests WHERE claim_id=$1 AND status='pending'",
        [id]);
      if(existing.rowCount){
        const old=existing.rows[0];
        if(old.customer_id===actor.id &&
          toTenThousandths(old.proposed_amount)===toTenThousandths(proposed) &&
          old.reason===reason) {
          return {adjustment_id:old.id,claim_id:id,status:'pending',replayed:true};
        }
        throw conflict('Another amount-adjustment request is already pending');
      }
      const requestId=randomUUID();
      await c.query(
        'INSERT INTO customer_claim_adjustment_requests '+
        '(id,claim_id,merchant_id,customer_id,original_amount,proposed_amount,reason) '+
        'VALUES($1,$2,$3,$4,$5::numeric,$6::numeric,$7)',
        [requestId,id,claim.merchant_id,actor.id,claim.amount.toString(),proposed,reason]);
      await this.store.audit(c,actor.id,'merchant_claim',id,'customer_requested_amount_adjustment',{
        adjustment_id:requestId,original_amount:claim.amount.toString(),
        proposed_amount:proposed,currency:claim.currency});
      return {adjustment_id:requestId,claim_id:id,status:'pending',replayed:false};
    });
  }

  async decide(actor,adjustmentId,body) {
    if(actor.role!=='merchant')throw new ApiError(403,'forbidden','Merchant role required');
    const id=uuid(adjustmentId,'adjustment_id');
    const selected=decision(body.decision);
    const target=selected==='accept'?'accepted':'rejected';
    return this.store.tx(async c=>{
      const initial=await c.query(
        'SELECT merchant_id,customer_id,claim_id FROM customer_claim_adjustment_requests WHERE id=$1',[id]);
      if(!initial.rowCount || initial.rows[0].merchant_id!==actor.id)throw missing();
      await this.store.lockRelationshipPair(c,actor.id,initial.rows[0].customer_id);
      const q=await c.query('SELECT * FROM customer_claim_adjustment_requests WHERE id=$1 FOR UPDATE',[id]);
      if(!q.rowCount)throw missing();
      const req=q.rows[0];
      if(req.status!=='pending'){
        if(req.status!==target)throw conflict('Adjustment was already decided differently');
        const old=await c.query(
          'SELECT superseded_by_claim_id FROM merchant_claims WHERE id=$1',[req.claim_id]);
        return {adjustment_id:id,status:target,source_claim_id:req.claim_id,
          replacement_claim_id:old.rows[0]?.superseded_by_claim_id??null,replayed:true};
      }
      const claim=await this.store.ensureEligible(c,req.claim_id,req.customer_id,{allowAdjustment:true});
      const decided=await c.query(
        'SELECT 1 FROM customer_claim_decisions WHERE claim_id=$1',[req.claim_id]);
      if(decided.rowCount)throw conflict('The original claim already has a customer decision');
      let replacement=null;
      if(target==='accepted'){
        const old=await c.query(
          'SELECT * FROM merchant_claims WHERE id=$1 AND merchant_id=$2 FOR UPDATE',
          [req.claim_id,actor.id]);
        if(!old.rowCount || old.rows[0].superseded_by_claim_id)throw conflict('Claim already superseded');
        const row=old.rows[0];
        const amount=money(req.proposed_amount.toString());
        const key='fin15-adjustment-'+id;
        replacement=randomUUID();
        const hash=claimDigest({contactId:row.contact_id,amount,currency:row.currency,
          description:row.description,type:row.operation_type});
        await c.query(
          'INSERT INTO merchant_claims '+
          '(id,merchant_id,contact_id,amount,currency,description,operation_type,occurred_at,'+
          'idempotency_key,request_digest,source_claim_id) '+
          'VALUES($1,$2,$3,$4::numeric,$5,$6,$7,$8,$9,$10,$11)',
          [replacement,row.merchant_id,row.contact_id,amount,row.currency,row.description,
            row.operation_type,row.occurred_at,key,hash,req.claim_id]);
        await c.query(
          'UPDATE merchant_claims SET superseded_by_claim_id=$2 WHERE id=$1',
          [req.claim_id,replacement]);
        await this.store.audit(c,actor.id,'merchant_claim',req.claim_id,
          'superseded_by_merchant_accepted_adjustment',{
            replacement_claim_id:replacement,adjustment_id:id});
        await this.store.audit(c,actor.id,'merchant_claim',replacement,
          'new_unacknowledged_replacement_requires_customer_approval',{
            original_claim_id:req.claim_id,adjustment_id:id});
      }
      await c.query(
        'UPDATE customer_claim_adjustment_requests SET status=$2,decided_at=clock_timestamp(),decided_by=$3 WHERE id=$1',
        [id,target,actor.id]);
      await this.store.audit(c,actor.id,'merchant_claim_adjustment',id,
        target==='accepted'?'merchant_accepted_proposal':'merchant_rejected_proposal',{
          original_claim_id:req.claim_id,replacement_claim_id:replacement});
      return {adjustment_id:id,status:target,source_claim_id:req.claim_id,
        replacement_claim_id:replacement,replayed:false};
    });
  }
}
