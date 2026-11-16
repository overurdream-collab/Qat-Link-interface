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
      const claim=path.match(/^\/v1\/customer\/previous-claims\/([\w-]+)\/decision$/);
      if(method==='POST' && claim){
        requireRole(actor,'customer');return json(res,200,await store.decideClaim(actor,claim[1],body));
      }
      const relationship=path.match(/^\/v1\/customer\/relationships\/([\w-]+)\/decision$/);
      if(method==='POST' && relationship){
        requireRole(actor,'customer');return json(res,200,await store.decideRelationship(actor,relationship[1],body));
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