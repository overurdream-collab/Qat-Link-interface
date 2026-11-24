import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createApi} from '../src/http.mjs';
import {createRequestMonitor} from '../src/monitoring.mjs';

test('readiness fails closed on missing/database failure, reveals no error and tracks status',async()=>{
  for(const readiness of [undefined,async()=>{throw new Error('synthetic-secret-OTP');},async()=>{}]) {
    const monitor=createRequestMonitor();
    const server=createApi({store:{},verify:()=>{throw new Error('auth must not run');},monitor,readiness});
    await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
    try {
      const response=await fetch(`http://127.0.0.1:${server.address().port}/readyz`);
      assert.equal(response.status,readiness===undefined?503:readiness.toString().includes('throw')?503:200);
      assert.doesNotMatch(await response.text(),/synthetic|secret|OTP/);
      assert.equal(monitor.snapshot().requests,1);
    } finally { await new Promise(resolve=>server.close(resolve)); }
  }
});
