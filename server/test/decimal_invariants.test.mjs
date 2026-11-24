import {test} from 'node:test';
import assert from 'node:assert/strict';
import {toTenThousandths,fromTenThousandths,ledgerSigned} from '../src/decimal.mjs';

test('seeded exact-money invariants: round trips, debt/payment cancellation and currency partitions',()=>{
  let seed=20261124n;
  const balances={YER:0n,SAR:0n,USD:0n};
  const currencies=Object.keys(balances);
  for(let i=0;i<10000;i++) {
    seed=(seed*6364136223846793005n+1442695040888963407n)%(1n<<64n);
    const units=seed%99999999999999999999n;
    const amount=fromTenThousandths(units);
    assert.equal(toTenThousandths(amount),units);
    assert.equal(ledgerSigned('debt',amount)+ledgerSigned('payment',amount),0n);
    const currency=currencies[i%3];
    balances[currency]+=ledgerSigned('debt',amount);
    balances[currency]+=ledgerSigned('payment',amount);
  }
  assert.deepEqual(balances,{YER:0n,SAR:0n,USD:0n});
});
