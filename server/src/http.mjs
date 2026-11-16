import { createServer } from 'node:http';
import { ApiError, page } from './validation.mjs';
import { requireRole } from './auth.mjs';

const json = (res,status,payload)=> {
  res.writeHead(status,{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'});
  res.end(JSON.stringify(payload));
};
async function readBody(req) {
  let size=0; const chunks=[];
  for await (const chunk of req) {
    size+=chunk.length;
    if(size>16384) throw new ApiError(413,'request_too_large','Request is too large');
    chunks.push(chunk);
  }
  if(!chunks.length) return {};
  try {
    const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if(!body || Array.isArray(body) || typeof body!=='object') throw new Error('body');
    return body;
  } catch {throw new ApiError(400,'invalid_json','Expected a JSON object');}
}
function requireParticipant(actor){
  if(!actor || !['merchant','customer'].includes(actor.role)) {
    throw new ApiError(403,'forbidden','Financial participant role required');
  }
}
export function createApi({store,verify}) {
  if(typeof verify!=='function') throw new Error('Verified authentication provider required');
  const handler=async (req,res)=>{
    try{
      if(req.url==='/healthz' && req.method==='GET') return json(res,200,{status:'ok',verified_auth:'required'});
      if(!req.url || req.url.length>2048) throw new ApiError(400,'bad_url','Invalid URL');
      const url=new URL(req.url,'http://localhost');
      const path=url.pathname;
      const actor=verify(req.headers.authorization);
      const method=req.method;
      if(method==='POST' && req.headers['content-type']?.split(';')[0].trim()!=='application/json')
        throw new ApiError(415,'unsupported_media','Expected application/json');
      const body=method==='POST'? await readBody(req) : {};
      if(method==='POST' && path==='/v1/internal/merchant-profiles'){
        requireRole(actor,'identity_service');return json(res,200,await store.onboardMerchant(actor,body));
      }
      if(method==='POST' && path==='/v1/internal/verified-phones'){
        requireRole(actor,'identity_service');return json(res,200,await store.verifyPhone(actor,body));
      }
      if(method==='POST' && path==='/v1/internal/revoke-phone-proof'){
        requireRole(actor,'identity_service');return json(res,200,await store.revokeProof(actor,body));
      }
      if(method==='POST' && path==='/v1/merchant/contacts'){
        requireRole(actor,'merchant');return json(res,201,await store.createContact(actor,body));
      }
      if(method==='POST' && path==='/v1/merchant/claims'){
        requireRole(actor,'merchant');
        const result=await store.createClaim(actor,body,req.headers['idempotency-key']);
        return json(res,result.replayed?200:201,{...result.claim,replayed:result.replayed});
      }
      if(method==='POST' && path==='/v1/merchant/relationship-requests'){
        requireRole(actor,'merchant');return json(res,201,await store.requestRelationship(actor,body));
      }
      if(method==='GET' && path==='/v1/merchant/contacts'){
        requireRole(actor,'merchant');
        return json(res,200,await store.listContacts(actor,{limit:page(url.searchParams.get('limit')??undefined),cursor:url.searchParams.get('cursor')}));
      }
      const merchantContactClaims=path.match(/^\/v1\/merchant\/contacts\/([\w-]+)\/claims$/);
      if(method==='GET' && merchantContactClaims){
        requireRole(actor,'merchant');
        return json(res,200,await store.listContactClaims(actor,merchantContactClaims[1],{limit:page(url.searchParams.get('limit')??undefined),cursor:url.searchParams.get('cursor')}));
      }
      if(method==='GET' && path==='/v1/merchant/claims/summary'){
        requireRole(actor,'merchant');return json(res,200,await store.summary(actor));
      }
      if(method==='GET' && path==='/v1/customer/previous-claims'){
        requireRole(actor,'customer');
        return json(res,200,await store.claimsInbox(actor,{limit:page(url.searchParams.get('limit')??undefined),cursor:url.searchParams.get('cursor')}));
      }
      if(method==='GET' && path==='/v1/customer/relationships'){
        requireRole(actor,'customer');
        return json(res,200,await store.listCustomerRelationships(actor,{limit:page(url.searchParams.get('limit')??undefined),cursor:url.searchParams.get('cursor')}));
      }
      // FIN-15: authenticated customer amount proposals; original financial
      // values remain untouched. Merchant resolution is a separate decision.
      const historicAmendment=path.match(/^\/v1\/customer\/previous-claims\/([\w-]+)\/amendments$/);
      if(method==='POST' && historicAmendment){
        requireRole(actor,'customer');
        const result=await store.amendments.requestHistorical(actor,historicAmendment[1],
          body,req.headers['idempotency-key']);
        return json(res,result.replayed?200:201,result);
      }
      const operationAmendment=path.match(/^\/v1\/relationships\/([\w-]+)\/operations\/([\w-]+)\/amendments$/);
      if(method==='POST' && operationAmendment){
        requireRole(actor,'customer');
        const result=await store.amendments.requestOperation(actor,operationAmendment[1],
          operationAmendment[2],body,req.headers['idempotency-key']);
        return json(res,result.replayed?200:201,result);
      }
      const merchantAmendment=path.match(/^\/v1\/merchant\/amendments\/([\w-]+)\/decision$/);
      if(method==='POST' && merchantAmendment){
        requireRole(actor,'merchant');
        return json(res,200,await store.amendments.decideMerchant(actor,merchantAmendment[1],body));
      }
      if(method==='GET' && (path==='/v1/merchant/amendments'||path==='/v1/customer/amendments')){
        requireRole(actor,path.startsWith('/v1/merchant/')?'merchant':'customer');
        return json(res,200,await store.amendments.list(actor,{
          limit:page(url.searchParams.get('limit')??undefined),
          cursor:url.searchParams.get('cursor')}));
      }
      const claim=path.match(/^\/v1\/customer\/previous-claims\/([\w-]+)\/decision$/);
      if(method==='POST' && claim){
        requireRole(actor,'customer');return json(res,200,await store.decideClaim(actor,claim[1],body));
      }
      const relationship=path.match(/^\/v1\/customer\/relationships\/([\w-]+)\/decision$/);
      if(method==='POST' && relationship){
        requireRole(actor,'customer');return json(res,200,await store.decideRelationship(actor,relationship[1],body));
      }
      // FIN-13: one authoritative APPROVED ledger for both legacy claims and
      // registered two-party requests. All identities come from JWT.
      if(method==='POST' && path==='/v1/customer/previous-claims/batch-decisions'){
        requireRole(actor,'customer');
        return json(res,200,await store.batch.decideHistoricalClaims(actor,body));
      }
      const operationBatch=path.match(/^\/v1\/relationships\/([\w-]+)\/operations\/batch-decisions$/);
      if(method==='POST' && operationBatch){
        requireParticipant(actor);
        return json(res,200,await store.batch.decideRelationshipOperations(actor,operationBatch[1],body));
      }
      const relOpDecision=path.match(/^\/v1\/relationships\/([\w-]+)\/operations\/([\w-]+)\/decision$/);
      if(method==='POST' && relOpDecision){
        requireParticipant(actor);
        return json(res,200,await store.ledger.decideOperation(actor,relOpDecision[1],relOpDecision[2],body));
      }
      const relOps=path.match(/^\/v1\/relationships\/([\w-]+)\/operations$/);
      if(relOps){
        requireParticipant(actor);
        if(method==='POST'){
          const result=await store.ledger.createOperation(actor,relOps[1],body,req.headers['idempotency-key']);
          return json(res,result.replayed?200:201,result);
        }
        if(method==='GET')return json(res,200,await store.ledger.operations(actor,relOps[1],{
          limit:page(url.searchParams.get('limit')??undefined),cursor:url.searchParams.get('cursor')}));
      }
      const reversal=path.match(/^\/v1\/relationships\/([\w-]+)\/reversals$/);
      if(method==='POST' && reversal){
        requireParticipant(actor);
        const result=await store.ledger.requestReversal(actor,reversal[1],body,req.headers['idempotency-key']);
        return json(res,result.replayed?200:201,result);
      }
      const credit=path.match(/^\/v1\/relationships\/([\w-]+)\/credit-limits$/);
      if(credit){
        requireParticipant(actor);
        if(method==='GET'){
          return json(res,200,await store.credit.getSnapshot(actor,credit[1]));
        }
        if(method==='POST'){
          return json(res,200,await store.credit.setPolicy(actor,credit[1],body));
        }
      }
      const balances=path.match(/^\/v1\/relationships\/([\w-]+)\/balances$/);
      if(method==='GET' && balances){
        requireParticipant(actor);return json(res,200,await store.ledger.balances(actor,balances[1]));
      }
      const statement=path.match(/^\/v1\/relationships\/([\w-]+)\/statement$/);
      if(method==='GET' && statement){
        requireParticipant(actor);return json(res,200,await store.ledger.statement(actor,statement[1],{
          currency:url.searchParams.get('currency'),from:url.searchParams.get('from'),to:url.searchParams.get('to')}));
      }
      const customerPolicy=path.match(/^\/v1\/customer\/relationships\/([\w-]+)\/auto-approval$/);
      if(method==='POST' && customerPolicy){
        requireRole(actor,'customer');
        return json(res,200,await store.ledger.setAutoApproval(actor,customerPolicy[1],body));
      }
      const policy=path.match(/^\/v1\/relationships\/([\w-]+)\/auto-approval$/);
      if(method==='GET' && policy){
        requireParticipant(actor);return json(res,200,await store.ledger.getAutoApproval(actor,policy[1]));
      }
      throw new ApiError(404,'not_found','Not found');
    }catch(err){
      if(err instanceof ApiError) return json(res,err.status,{error:err.code,message:err.message});
      // Never leak SQL, phone, token, personal data or implementation details.
      console.error('[fin08] internal request error',err?.code ?? err?.name ?? 'Error');
      return json(res,500,{error:'internal_error',message:'Request could not be completed'});
    }
  };
  return createServer(handler);
}