// Trusted identity-service-to-financial-service provisioning.
// This is NOT an approval of a merchant/customer relationship or a debt.
import { signIdentityJwt, IdentityError } from './identity_logic.mjs';

export function createFinanceProvisioner({ fetchImpl, settings }) {
  const {financeBaseUrl, privateKey, issuer, audience} = settings;
  const origin = new URL(financeBaseUrl);
  if (!['http:','https:'].includes(origin.protocol) ||
      origin.username || origin.password || origin.search || origin.hash ||
      (origin.pathname && origin.pathname !== '/')) {
    throw new Error('Invalid FIN08 internal URL');
  }
  async function provision({account, phone}) {
    if (!['merchant','customer'].includes(account.role)) throw new IdentityError(403,'Invalid role');
    if (!/^[+]967[0-9]{9}$/.test(phone)) throw new IdentityError(400,'Invalid phone');
    const customer = account.role === 'customer';
    const path = customer ? 'v1/internal/verified-phones' : 'v1/internal/merchant-profiles';
    if(customer && !account.finance_proof_reference) throw new Error('Missing phone proof reference');
    if(!customer && !account.display_name) throw new Error('Missing merchant name');
    const payload = customer
      ? {customer_id:account.subject,phone,proof_reference:account.finance_proof_reference}
      : {merchant_id:account.subject,verified_display_name:account.display_name};
    const token = signIdentityJwt({privateKey,issuer,audience,
      subject:'maqwati-identity-service',role:'identity_service',lifetimeSeconds:60});
    const controller = new AbortController();
    const timer = setTimeout(()=>controller.abort(),8000);
    try {
      const response = await fetchImpl(new URL(path,origin).toString(),{
        method:'POST',
        headers:{'content-type':'application/json','authorization':'Bearer '+token},
        body:JSON.stringify(payload),redirect:'error',signal:controller.signal
      });
      if(!response.ok) throw new IdentityError(503,'Financial provisioning unavailable');
      const result=await response.json();
      if(customer && result?.conflict === true) throw new IdentityError(409,'Phone ownership conflict requires review');
      if(!customer && (result?.merchant_id !== account.subject)) throw new IdentityError(502,'Invalid financial registration');
      return true;
    }catch(e){
      if(e instanceof IdentityError) throw e;
      throw new IdentityError(503,'Financial provisioning unavailable');
    }finally {clearTimeout(timer);}
  }
  return {provision};
}
