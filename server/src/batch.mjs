import { ApiError, uuid, decision } from './validation.mjs';
import { fromTenThousandths, toTenThousandths } from './decimal.mjs';

const missing=()=>new ApiError(404,'not_found','One or more selected operations were not found');
const conflict=message=>new ApiError(409,'conflict',message);

function selection(body){
  if(!body || !Array.isArray(body.decisions) ||
      body.decisions.length<1 || body.decisions.length>50) {
    throw new ApiError(422,'invalid_input','Select between 1 and 50 operations');
  }
  const choices=body.decisions.map((entry)=>{
    if(!entry || typeof entry!=='object' || Array.isArray(entry)) {
      throw new ApiError(422,'invalid_input','Malformed selected operation');
    }
    return {id:uuid(entry.id,'operation id'),decision:decision(entry.decision)};
  });
  if(new Set(choices.map(x=>x.id)).size!==choices.length) {
    throw new ApiError(422,'invalid_input','Duplicate operation in batch');
  }
  // Lock all affected rows in stable order irrespective of UI selection order.
  return choices.sort((a,b)=>a.id.localeCompare(b.id));
}
function reviewTotals(rows) {
  const perCurrency=new Map();
  for(const row of rows){
    if(!perCurrency.has(row.currency))perCurrency.set(row.currency,{debts:0n,payments:0n});
    const bucket=perCurrency.get(row.currency);
    const value=toTenThousandths(row.amount);
    if(row.type==='debt')bucket.debts+=value;
    else if(row.type==='payment')bucket.payments+=value;
    else throw new Error('Unsupported financial type');
  }
  return ['YER','SAR','USD'].map(currency=>{
    const bucket=perCurrency.get(currency)??{debts:0n,payments:0n};
    return {currency,selected_debts:fromTenThousandths(bucket.debts),
      selected_payments:fromTenThousandths(bucket.payments),
      selected_net_estimate:fromTenThousandths(bucket.debts-bucket.payments)};
  });
}

/** FIN-14: all-or-nothing server decisions, never "accept all" implicitly.
 * This service writes no approved balances directly: it reuses FIN-08/13
 * unique-source and two-party ledger posting inside the SAME transaction.
 */
export class Fin14BatchService {
  constructor(store){this.store=store;}

  async decideHistoricalClaims(actor,body) {
    const choices=selection(body);
    const ids=choices.map(x=>x.id);
    return this.store.tx(async c=>{
      const initial=await c.query('SELECT id,merchant_id FROM merchant_claims WHERE id=ANY($1::uuid[]) ORDER BY merchant_id,id',
        [ids]);
      if(initial.rows.length!==ids.length)throw missing();
      for(const merchantId of [...new Set(initial.rows.map(x=>x.merchant_id))].sort()){
        await this.store.lockRelationshipPair(c,merchantId,actor.id);
      }
      const selectedRows=[];
      const result=[];
      for(const choice of choices){
        // This enforces current verified phone ownership on EACH claim and
        // obtains a row lock before any decision is entered.
        const claim=await this.store.ensureEligible(c,choice.id,actor.id);
        const kind=await c.query('SELECT operation_type,amount::text,currency FROM merchant_claims WHERE id=$1',
          [choice.id]);
        const row=kind.rows[0];
        selectedRows.push({currency:row.currency,amount:row.amount,type:row.operation_type});
        const ins=await c.query('INSERT INTO customer_claim_decisions(claim_id,merchant_id,customer_id,decision) VALUES($1,$2,$3,$4) ON CONFLICT (claim_id) DO NOTHING RETURNING decision',
          [choice.id,claim.merchant_id,actor.id,choice.decision]);
        if(!ins.rowCount){
          const previous=await c.query('SELECT decision,customer_id FROM customer_claim_decisions WHERE claim_id=$1',
            [choice.id]);
          if(!previous.rowCount || previous.rows[0].customer_id!==actor.id ||
              previous.rows[0].decision!==choice.decision)throw conflict('A selected claim already has a different decision');
        }else await this.store.audit(c,actor.id,'merchant_claim',choice.id,
          'customer_'+choice.decision+'_in_selective_batch');
        const posted=choice.decision==='accept'?
          await this.store.postClaim(c,choice.id,actor.id):false;
        result.push({id:choice.id,decision:choice.decision,replayed:!ins.rowCount,ledger_posted:posted});
      }
      await this.store.audit(c,actor.id,'claim_batch',actor.id,'batch_completed',
        {count:result.length,posted:result.filter(x=>x.ledger_posted).length});
      return {items:result,reviewed_by_currency:reviewTotals(selectedRows),
        newly_posted_count:result.filter(x=>x.ledger_posted).length,
        scope:'selected_claims_only'};
    });
  }

  async decideRelationshipOperations(actor,relationshipId,body) {
    const choices=selection(body);
    const relId=uuid(relationshipId,'relationship_id');
    return this.store.tx(async c=>{
      const rel=await this.store.ledger.relationship(c,actor,relId,{lock:true,write:true});
      if(rel.status!=='approved')throw conflict('Relationship is not approved');
      const ids=choices.map(x=>x.id);
      const fetched=await c.query([
        'SELECT id,operation_type,amount::text,currency,created_by,created_by_role,status,approval_method',
        'FROM relationship_operations WHERE relationship_id=$1 AND id=ANY($2::uuid[])',
        'ORDER BY id FOR UPDATE'
      ].join(' '),[relId,ids]);
      if(fetched.rows.length!==ids.length)throw missing();
      const map=new Map(fetched.rows.map(x=>[x.id,x]));
      const selectedRows=[];
      const result=[];
      for(const choice of choices){
        const op=map.get(choice.id);
        if(!op || op.created_by===actor.id || op.created_by_role===actor.role){
          throw new ApiError(403,'forbidden','Cannot decide own financial request');
        }
        selectedRows.push({currency:op.currency,amount:op.amount,type:op.operation_type});
        const wanted=choice.decision==='accept'?'approved':'rejected';
        if(op.status!=='pending'){
          if(op.status!==wanted||op.approval_method!=='manual'){
            throw conflict('Selected operation was already decided differently');
          }
          result.push({id:choice.id,status:wanted,replayed:true,ledger_posted:false});
          continue;
        }
        await c.query('UPDATE relationship_operations SET status=$2,decided_at=clock_timestamp(),decided_by=$3 WHERE id=$1',
          [op.id,wanted,actor.id]);
        await this.store.audit(c,actor.id,'operation',op.id,
          'other_party_'+wanted+'_in_selective_batch');
        const posted=wanted==='approved'?
          await this.store.ledger.postOperation(c,op.id,actor.id):false;
        result.push({id:choice.id,status:wanted,replayed:false,ledger_posted:posted});
      }
      await this.store.audit(c,actor.id,'operation_batch',relId,'batch_completed',
        {count:result.length,posted:result.filter(x=>x.ledger_posted).length});
      return {relationship_id:relId,items:result,
        reviewed_by_currency:reviewTotals(selectedRows),
        newly_posted_count:result.filter(x=>x.ledger_posted).length,
        scope:'selected_relationship_operations_only'};
    });
  }
}
