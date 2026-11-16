import { randomUUID } from 'node:crypto';
import { ApiError, currency, uuid } from './validation.mjs';
import { fromTenThousandths, toTenThousandths } from './decimal.mjs';

const conflict=message=>new ApiError(409,'credit_limit_exceeded',message);
function limitAmount(value){
  if(typeof value!=='string'|| !/^\d{1,16}(?:\.\d{1,4})?$/.test(value)){
    throw new ApiError(422,'invalid_input','Credit limit must be a nonnegative Decimal string (4 places maximum)');
  }
  return fromTenThousandths(toTenThousandths(value));
}
const missing=()=>new ApiError(404,'not_found','Relationship not found');

export class Fin16CreditService {
  constructor(store){this.store=store;}

  // The relationship advisory lock has already been obtained by
  // ledger.createOperation(). This query and the creation occur in one TX.
  // PENDING claims are risk metrics, never approved entries or hard-block inputs.
  async evaluateNewDebt(c,relationshipId,unit,amount){
    const q=await c.query([
      'SELECT limit_amount::text AS limit_amount,mode FROM relationship_credit_limits',
      'WHERE relationship_id=$1 AND currency=$2 AND enabled=TRUE'
    ].join(' '),[relationshipId,unit]);
    if(!q.rowCount)return null;
    const approved=await c.query([
      'SELECT COALESCE(SUM(CASE WHEN type=\'debt\' THEN amount ELSE -amount END),0)::text AS balance',
      'FROM financial_movements WHERE relationship_id=$1 AND currency=$2'
    ].join(' '),[relationshipId,unit]);
    const approvedNet=toTenThousandths(approved.rows[0].balance);
    const proposed=approvedNet+toTenThousandths(amount);
    const cap=toTenThousandths(q.rows[0].limit_amount);
    if(proposed<=cap)return null;
    if(q.rows[0].mode==='block'){
      throw conflict('New debt would exceed this merchant credit limit for '+unit+
        '. Review the approved balance and per-currency policy.');
    }
    return {
      currency:unit,mode:'warn',limit_amount:fromTenThousandths(cap),
      approved_balance:fromTenThousandths(approvedNet),
      projected_balance:fromTenThousandths(proposed),
      scope:'approved_balance_plus_this_new_debt_not_pending_claims'
    };
  }

  async getSnapshot(actor,relationshipId){
    const id=uuid(relationshipId,'relationship_id');
    return this.store.tx(async c=>{
      const rel=await this.store.ledger.relationship(c,actor,id);
      if(rel.status!=='approved')throw missing();
      const policies=await c.query([
        'SELECT currency,enabled,version,mode,limit_amount::text AS limit_amount,',
        'updated_at FROM relationship_credit_limits WHERE relationship_id=$1'
      ].join(' '),[id]);
      const ledgers=await c.query([
        'SELECT currency,COALESCE(SUM(CASE WHEN type=\'debt\' THEN amount ELSE -amount END),0)::text AS approved_balance',
        'FROM financial_movements WHERE relationship_id=$1 GROUP BY currency'
      ].join(' '),[id]);
      const ops=await c.query([
        'SELECT currency,',
        'COALESCE(SUM(CASE WHEN operation_type=\'debt\' THEN amount ELSE 0 END),0)::text AS debts,',
        'COALESCE(SUM(CASE WHEN operation_type=\'payment\' THEN amount ELSE 0 END),0)::text AS payments',
        'FROM relationship_operations WHERE relationship_id=$1 AND status=\'pending\' GROUP BY currency'
      ].join(' '),[id]);
      const historic=await c.query([
        'SELECT cl.currency,',
        'COALESCE(SUM(CASE WHEN cl.operation_type=\'debt\' THEN cl.amount ELSE 0 END),0)::text AS debts,',
        'COALESCE(SUM(CASE WHEN cl.operation_type=\'payment\' THEN cl.amount ELSE 0 END),0)::text AS payments',
        'FROM merchant_claims cl',
        'LEFT JOIN customer_claim_decisions d ON d.claim_id=cl.id',
        'LEFT JOIN financial_movements fm ON fm.source_claim_id=cl.id',
        'WHERE cl.merchant_id=$1 AND cl.contact_id=$2',
        'AND cl.superseded_by_claim_id IS NULL',
        'AND d.decision IS DISTINCT FROM \'reject\' AND fm.id IS NULL',
        'GROUP BY cl.currency'
      ].join(' '),[rel.merchant_id,rel.contact_id]);
      const pm=new Map(policies.rows.map(x=>[x.currency,x]));
      const lm=new Map(ledgers.rows.map(x=>[x.currency,x]));
      const om=new Map(ops.rows.map(x=>[x.currency,x]));
      const hm=new Map(historic.rows.map(x=>[x.currency,x]));
      return {relationship_id:id,scope:'approved_ledger_and_separate_unapproved_exposure',
        currencies:['YER','SAR','USD'].map(unit=>{
          const p=pm.get(unit);
          const approved=lm.get(unit)?.approved_balance??'0.0000';
          const debts=toTenThousandths(om.get(unit)?.debts??'0.0000')+
            toTenThousandths(hm.get(unit)?.debts??'0.0000');
          const payments=toTenThousandths(om.get(unit)?.payments??'0.0000')+
            toTenThousandths(hm.get(unit)?.payments??'0.0000');
          const active=p?.enabled===true;
          const limit=active?p.limit_amount:null;
          const exceeded=active?toTenThousandths(approved)>toTenThousandths(limit):false;
          return {
            currency:unit,enabled:active,limit_amount:limit,mode:active?p.mode:null,
            version:p?.version??0,updated_at:p?.updated_at??null,
            approved_balance:approved,
            pending_debts:fromTenThousandths(debts),
            pending_payments:fromTenThousandths(payments),
            pending_net_estimate:fromTenThousandths(debts-payments),
            approved_exceeds_limit:exceeded
          };
        })};
    });
  }

  async setPolicy(actor,relationshipId,body){
    if(actor.role!=='merchant')throw new ApiError(403,'forbidden','Only the merchant can configure credit limits');
    const id=uuid(relationshipId,'relationship_id');
    const unit=currency(body.currency);
    if(typeof body.enabled!=='boolean')throw new ApiError(422,'invalid_input','enabled must be boolean');
    const enabled=body.enabled;
    let amount=null,mode=null;
    if(enabled){
      amount=limitAmount(body.limit_amount);
      mode=body.mode;
      if(mode!=='warn' && mode!=='block')throw new ApiError(422,'invalid_input','mode must be warn or block');
    }
    return this.store.tx(async c=>{
      const rel=await this.store.ledger.relationship(c,actor,id,{lock:true,write:true});
      if(rel.status!=='approved')throw new ApiError(409,'conflict','An approved relationship is required');
      const original=await c.query([
        'SELECT limit_amount::text AS limit_amount,mode,enabled,version',
        'FROM relationship_credit_limits WHERE relationship_id=$1 AND currency=$2 FOR UPDATE'
      ].join(' '),[id,unit]);
      const prior=original.rows[0];
      if((!enabled && !prior?.enabled) ||
        (enabled && prior?.enabled && prior.mode===mode &&
         toTenThousandths(prior.limit_amount)===toTenThousandths(amount))){
        return {relationship_id:id,currency:unit,enabled:!!prior?.enabled,
          mode:prior?.enabled?prior.mode:null,
          limit_amount:prior?.enabled?prior.limit_amount:null,
          version:prior?.version??0,replayed:true};
      }
      if(!enabled){
        const disabled=await c.query([
          'UPDATE relationship_credit_limits SET enabled=FALSE,version=version+1,',
          'updated_by=$3,updated_at=clock_timestamp()',
          'WHERE relationship_id=$1 AND currency=$2 RETURNING version'
        ].join(' '),[id,unit,actor.id]);
        const version=disabled.rows[0].version;
        await c.query([
          'INSERT INTO relationship_credit_limit_events',
          '(id,relationship_id,currency,actor_id,action,version,previous_amount,previous_mode)',
          'VALUES($1,$2,$3,$4,\'disable\',$5,$6::numeric,$7)'
        ].join(' '),[randomUUID(),id,unit,actor.id,version,prior.limit_amount,prior.mode]);
        await this.store.audit(c,actor.id,'relationship_credit_limit',id,'disabled',{currency:unit,version});
        return {relationship_id:id,currency:unit,enabled:false,limit_amount:null,
          mode:null,version,replayed:false};
      }
      const updated=await c.query([
        'INSERT INTO relationship_credit_limits',
        '(relationship_id,currency,limit_amount,mode,enabled,version,updated_by)',
        'VALUES($1,$2,$3::numeric,$4,TRUE,1,$5)',
        'ON CONFLICT(relationship_id,currency) DO UPDATE SET',
        'limit_amount=EXCLUDED.limit_amount,mode=EXCLUDED.mode,enabled=TRUE,',
        'version=relationship_credit_limits.version+1,',
        'updated_by=EXCLUDED.updated_by,updated_at=clock_timestamp()',
        'RETURNING version'
      ].join(' '),[id,unit,amount,mode,actor.id]);
      const version=updated.rows[0].version;
      await c.query([
        'INSERT INTO relationship_credit_limit_events',
        '(id,relationship_id,currency,actor_id,action,version,previous_amount,previous_mode,limit_amount,mode)',
        'VALUES($1,$2,$3,$4,\'set\',$5,$6::numeric,$7,$8::numeric,$9)'
      ].join(' '),[randomUUID(),id,unit,actor.id,version,prior?.limit_amount??null,
        prior?.mode??null,amount,mode]);
      await this.store.audit(c,actor.id,'relationship_credit_limit',id,'set',
        {currency:unit,mode,limit_amount:amount,version});
      return {relationship_id:id,currency:unit,enabled:true,
        mode,limit_amount:amount,version,replayed:false};
    });
  }
}
