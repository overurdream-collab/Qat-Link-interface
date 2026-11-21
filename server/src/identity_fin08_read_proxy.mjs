// Only explicitly allowlisted FIN08 read operations go through the existing
// Identity container. No mutation or arbitrary URL forwarding is possible.
import { IdentityError } from './identity_logic.mjs';

const routeRole = [
  { pattern: /^\/v1\/merchant\/contacts$/, role: 'merchant' },
  { pattern: /^\/v1\/merchant\/contacts\/[a-f0-9-]{36}\/claims$/i, role: 'merchant' },
  { pattern: /^\/v1\/merchant\/claims\/summary$/, role: 'merchant' },
  { pattern: /^\/v1\/customer\/relationships$/, role: 'customer' },
  { pattern: /^\/v1\/customer\/previous-claims$/, role: 'customer' },
];

export function createIdentityFinanceReadProxy({ fetchImpl, financeBaseUrl }) {
  if(typeof fetchImpl !== 'function') throw new TypeError('fetch required');
  const base=new URL(financeBaseUrl);
  if (!['http:','https:'].includes(base.protocol) || base.username || base.password ||
      base.search || base.hash || base.pathname !== '/') {
    throw new TypeError('Invalid private FIN08 origin');
  }
  return async function readFinance({ method, url, authorization, account }) {
    if(method!=='GET') throw new IdentityError(404,'Not found');
    const path=new URL(url,'http://localhost');
    const match=routeRole.find(item=>item.pattern.test(path.pathname));
    if(!match) throw new IdentityError(404,'Not found');
    if(!account || account.role!==match.role) throw new IdentityError(403,'Role not allowed');
    if(typeof authorization!=='string' || !authorization.startsWith('Bearer ')) {
      throw new IdentityError(401,'Authentication required');
    }
    // Pagination is the only supported query input. The actual FIN08 service
    // validates cursor ownership and the account-scoped JWT independently.
    for(const key of path.searchParams.keys()) {
      if(!['cursor','limit'].includes(key)) throw new IdentityError(400,'Invalid query');
    }
    const target=new URL(path.pathname+path.search,base);
    const abort=new AbortController();
    const timer=setTimeout(()=>abort.abort(),8000);
    try {
      const result=await fetchImpl(target,{
        method:'GET',
        headers:{authorization,accept:'application/json'},
        redirect:'error',
        signal:abort.signal
      });
      if(result.status===401 || result.status===403) {
        throw new IdentityError(result.status,'FIN08 access denied');
      }
      if(!result.ok) throw new IdentityError(503,'Financial data unavailable');
      const type=result.headers.get('content-type') || '';
      if(!type.toLowerCase().includes('application/json')) throw new IdentityError(502,'Invalid financial response');
      // Bound memory and output; never log or cache private financial records.
      const length=Number(result.headers.get('content-length'));
      if(Number.isFinite(length) && length>512_000) throw new IdentityError(502,'Response too large');
      const reader=result.body?.getReader();
      if(!reader) throw new IdentityError(502,'Invalid financial response');
      const parts=[];let size=0;
      while(true){
        const {done,value}=await reader.read();
        if(done)break;
        size+=value.length;
        if(size>512_000){await reader.cancel();throw new IdentityError(502,'Response too large')}
        parts.push(value);
      }
      const body=Buffer.concat(parts).toString('utf8');
      let data;try {data=JSON.parse(body)}catch{throw new IdentityError(502,'Invalid financial response')}
      if(!data || typeof data!=='object' || Array.isArray(data)) throw new IdentityError(502,'Invalid financial response');
      return data;
    } catch(e) {
      if(e instanceof IdentityError)throw e;
      throw new IdentityError(503,'Financial data unavailable');
    } finally {clearTimeout(timer)}
  };
}
