import { createHash, randomUUID } from 'node:crypto';
import { ApiError, currency, idempotencyKey, money, uuid } from './validation.mjs';
import { fromTenThousandths, toTenThousandths } from './decimal.mjs';

const missing=()=>new ApiError(404,'not_found','Payment, debt, or allocation not found');
const conflict=message=>new ApiError(409,'conflict',message);
const digest=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');

export class Fin17SettlementService {
  constructor(store){this.store=store;}

  async loadPair(c,relationshipId,paymentId,debtId,{lock=false}={}) {
    const suffix=lock?' FOR UPDATE':'';
    const q=await c.query([
      'SELECT id,relationship_id,amount::text AS amount,currency,type',
      'FROM financial_movements WHERE id=ANY($1::uuid[]) ORDER BY id'+suffix
    ].join(' '),[[paymentId,debtId]]);
    const payment=q.rows.find(x=>x.id===paymentId);
    const debt=q.rows.find(x=>x.id===debtId);
    if(!payment||!debt||payment.relationship_id!==relationshipId||
       debt.relationship_id!==relationshipId||payment.type!=='payment'||debt.type!=='debt') throw missing();
    if(payment.currency!==debt.currency) throw new ApiError(422,'currency_mismatch','Payment and debt must use the same currency');
    const pendingReverse=await c.query([
      'SELECT 1 FROM relationship_operations WHERE reversal_of_movement_id=ANY($1::uuid[])',
      'AND status IN (\'pending\',\'approved\') LIMIT 1'
    ].join(' '),[[paymentId,debtId]]);
    const postedReverse=await c.query(
      'SELECT reversal_of_movement_id FROM financial_movements WHERE reversal_of_movement_id=ANY($1::uuid[])',
      [[paymentId,debtId]]);
    const reversed=new Set(postedReverse.rows.map(x=>x.reversal_of_movement_id));
    if(pendingReverse.rowCount||reversed.has(paymentId)||reversed.has(debtId)) {
      throw conflict('Reversed or reversing movements cannot receive new allocations');
    }
    return {payment,debt};
  }

  async netFor(c,where,value) {
    const q=await c.query([
      'SELECT COALESCE(SUM(CASE WHEN action=\'allocate\' THEN amount ELSE -amount END),0)::text AS amount',
      'FROM financial_payment_allocation_entries WHERE '+where+'=$1'
    ].join(' '),[value]);
    return toTenThousandths(q.rows[0].amount);
  }

  async effectiveAmount(c,movement) {
    const reversed=await c.query([
      'SELECT COALESCE(SUM(amount),0)::text AS amount FROM financial_movements',
      'WHERE reversal_of_movement_id=$1'
    ].join(' '),[movement.id]);
    return toTenThousandths(movement.amount)-toTenThousandths(reversed.rows[0].amount);
  }

  async request(actor,relationshipId,body,key) {
    const relId=uuid(relationshipId,'relationship_id');
    const paymentId=uuid(body.payment_movement_id,'payment_movement_id');
    const debtId=uuid(body.debt_movement_id,'debt_movement_id');
    const amount=money(body.amount);
    const action=body.action;
    if(action!=='allocate'&&action!=='release') throw new ApiError(422,'invalid_input','action must be allocate or release');
    const allocationId=action==='release'?uuid(body.allocation_id,'allocation_id'):null;
    const idempotency=idempotencyKey(key);
    const requestDigest=digest([relId,action,paymentId,debtId,allocationId,amount]);
    return this.store.tx(async c=>{
      const rel=await this.store.ledger.relationship(c,actor,relId,{lock:true,write:true});
      if(rel.status!=='approved') throw conflict('An approved relationship is required');
      const prior=await c.query('SELECT id,status,request_digest FROM financial_payment_allocation_requests WHERE requested_by=$1 AND idempotency_key=$2',
        [actor.id,idempotency]);
      if(prior.rowCount){
        if(prior.rows[0].request_digest!==requestDigest) throw conflict('Idempotency-Key reused with different allocation request');
        return {request_id:prior.rows[0].id,status:prior.rows[0].status,replayed:true};
      }
      const {payment,debt}=await this.loadPair(c,relId,paymentId,debtId);
      if(action==='allocate') {
        const allocated=await this.netFor(c,'payment_movement_id',paymentId);
        const debtAllocated=await this.netFor(c,'debt_movement_id',debtId);
        const paymentCapacity=await this.effectiveAmount(c,payment)-allocated;
        const debtCapacity=await this.effectiveAmount(c,debt)-debtAllocated;
        if(toTenThousandths(amount)>paymentCapacity||toTenThousandths(amount)>debtCapacity)
          throw conflict('Allocation exceeds the unallocated payment or remaining debt');
      } else {
        const bucket=await c.query([
          'SELECT payment_movement_id,debt_movement_id FROM financial_payment_allocation_requests',
          'WHERE id=$1 AND action=\'allocate\' AND status=\'approved\''
        ].join(' '),[allocationId]);
        if(!bucket.rowCount||bucket.rows[0].payment_movement_id!==paymentId||
           bucket.rows[0].debt_movement_id!==debtId) throw missing();
        const allocated=await this.netFor(c,'allocation_id',allocationId);
        if(toTenThousandths(amount)>allocated) throw conflict('Release exceeds the remaining allocated amount');
      }
      const requestId=randomUUID();
      await c.query([
        'INSERT INTO financial_payment_allocation_requests',
        '(id,relationship_id,merchant_id,customer_id,action,payment_movement_id,debt_movement_id,allocation_id,amount,',
        'requested_by,requested_by_role,idempotency_key,request_digest)',
        'VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9::numeric,$10,$11,$12,$13)'
      ].join(' '),[requestId,relId,rel.merchant_id,rel.customer_id,action,paymentId,debtId,
        allocationId,amount,actor.id,actor.role,idempotency,requestDigest]);
      await this.store.audit(c,actor.id,'payment_allocation_request',requestId,
        action==='allocate'?'allocation_requested_pending_other_party':'release_requested_pending_other_party',
        {relationship_id:relId,payment_movement_id:paymentId,debt_movement_id:debtId,
          allocation_id:allocationId,amount,currency:payment.currency});
      return {request_id:requestId,status:'pending',action,amount,currency:payment.currency,replayed:false};
    });
  }

  async decide(actor,relationshipId,requestId,body) {
    const relId=uuid(relationshipId,'relationship_id');
    const reqId=uuid(requestId,'request_id');
    if(body.decision!=='accept'&&body.decision!=='reject')
      throw new ApiError(422,'invalid_input','decision must be accept or reject');
    return this.store.tx(async c=>{
      const rel=await this.store.ledger.relationship(c,actor,relId,{lock:true,write:true});
      if(rel.status!=='approved') throw conflict('An approved relationship is required');
      const q=await c.query('SELECT * FROM financial_payment_allocation_requests WHERE id=$1 AND relationship_id=$2 FOR UPDATE',[reqId,relId]);
      if(!q.rowCount) throw missing();
      const item=q.rows[0];
      if(item.requested_by===actor.id||item.requested_by_role===actor.role)
        throw new ApiError(403,'forbidden','Only the other participant can decide');
      const target=body.decision==='accept'?'approved':'rejected';
      if(item.status!=='pending'){
        if(item.status!==target) throw conflict('Allocation request already decided');
        return {request_id:reqId,status:target,replayed:true};
      }
      if(target==='approved'){
        const {payment,debt}=await this.loadPair(c,relId,item.payment_movement_id,item.debt_movement_id,{lock:true});
        const amount=toTenThousandths(item.amount);
        if(item.action==='allocate'){
          const allocated=await this.netFor(c,'payment_movement_id',item.payment_movement_id);
          const debtAllocated=await this.netFor(c,'debt_movement_id',item.debt_movement_id);
          if(amount>await this.effectiveAmount(c,payment)-allocated||
             amount>await this.effectiveAmount(c,debt)-debtAllocated)
            throw conflict('Allocation no longer fits the remaining payment or debt');
        } else {
          const allocated=await this.netFor(c,'allocation_id',item.allocation_id);
          if(amount>allocated) throw conflict('Release exceeds the remaining allocated amount');
        }
        const allocationId=item.action==='allocate'?reqId:item.allocation_id;
        await c.query([
          'INSERT INTO financial_payment_allocation_entries',
          '(id,request_id,allocation_id,relationship_id,payment_movement_id,debt_movement_id,action,amount)',
          'VALUES($1,$2,$3,$4,$5,$6,$7,$8::numeric)'
        ].join(' '),[randomUUID(),reqId,allocationId,relId,item.payment_movement_id,
          item.debt_movement_id,item.action,item.amount]);
      }
      await c.query('UPDATE financial_payment_allocation_requests SET status=$2,decided_by=$3,decided_at=clock_timestamp() WHERE id=$1',
        [reqId,target,actor.id]);
      await this.store.audit(c,actor.id,'payment_allocation_request',reqId,
        target==='approved'?'allocation_request_approved':'allocation_request_rejected',
        {action:item.action,amount:item.amount,allocation_id:item.allocation_id});
      return {request_id:reqId,status:target,replayed:false};
    });
  }

  async forPayment(actor,relationshipId,paymentId) {
    const relId=uuid(relationshipId,'relationship_id');
    const payId=uuid(paymentId,'payment_movement_id');
    return this.store.tx(async c=>{
      await this.store.ledger.relationship(c,actor,relId);
      const q=await c.query('SELECT id,relationship_id,amount::text AS amount,currency,type FROM financial_movements WHERE id=$1 AND relationship_id=$2',[payId,relId]);
      if(!q.rowCount||q.rows[0].type!=='payment') throw missing();
      const payment=q.rows[0];
      const effective=await this.effectiveAmount(c,payment);
      const events=await c.query([
        'SELECT e.allocation_id,e.debt_movement_id,e.action,e.amount::text,e.created_at,',
        'r.id AS request_id,r.requested_by,r.requested_at,r.decided_by,r.decided_at',
        'FROM financial_payment_allocation_entries e JOIN financial_payment_allocation_requests r ON r.id=e.request_id',
        'WHERE e.payment_movement_id=$1 ORDER BY e.created_at,e.id'
      ].join(' '),[payId]);
      const current=new Map();
      const history=events.rows.map(e=>{
        const value=toTenThousandths(e.amount);
        current.set(e.allocation_id,(current.get(e.allocation_id)||0n)+(e.action==='allocate'?value:-value));
        return {allocation_id:e.allocation_id,debt_movement_id:e.debt_movement_id,
          action:e.action,amount:e.amount,requested_by:e.requested_by,requested_at:e.requested_at,
          decided_by:e.decided_by,decided_at:e.decided_at,recorded_at:e.created_at};
      });
      const active=[...current.entries()].filter(([,amount])=>amount>0n)
        .map(([allocation_id,amount])=>({allocation_id,allocated_amount:fromTenThousandths(amount)}));
      const allocated=[...current.values()].reduce((sum,n)=>sum+n,0n);
      return {relationship_id:relId,payment_movement_id:payId,currency:payment.currency,
        approved_payment_amount:payment.amount,available_after_reversals:fromTenThousandths(effective),
        allocated_amount:fromTenThousandths(allocated),
        unallocated_credit:fromTenThousandths(effective-allocated),
        allocations:active,history,scope:'approved_payment_allocations_do_not_change_ledger_balance'};
    });
  }
}
