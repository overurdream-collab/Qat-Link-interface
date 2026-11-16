// Exact decimal arithmetic at the PostgreSQL NUMERIC(20,4) scale.
// Never use Number, parseFloat or IEEE-754 arithmetic for money.
export function toTenThousandths(value) {
  if (typeof value !== 'string' || !/^-?\d+(?:\.\d{1,4})?$/.test(value)) {
    throw new TypeError('Expected a decimal string with at most four places');
  }
  const negative=value.startsWith('-');
  const unsigned=negative?value.slice(1):value;
  const [whole,fraction='']=unsigned.split('.');
  const scaled=BigInt(whole)*10000n+BigInt(fraction.padEnd(4,'0'));
  return negative?-scaled:scaled;
}
export function fromTenThousandths(value) {
  if (typeof value !== 'bigint') throw new TypeError('Expected BigInt');
  const abs=value<0n?-value:value;
  return (value<0n?'-':'')+(abs/10000n).toString()+'.'+
    (abs%10000n).toString().padStart(4,'0');
}
export function ledgerSigned(type,amount) {
  if(type!=='debt' && type!=='payment') throw new TypeError('Invalid ledger type');
  const scaled=toTenThousandths(amount);
  return type==='debt'?scaled:-scaled;
}
