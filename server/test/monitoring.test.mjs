import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequestMonitor} from '../src/monitoring.mjs';

test('request monitor separates security events without retaining arbitrary labels or payloads',()=>{
  const monitor=createRequestMonitor();
  for(const status of [200,401,403,409,429,500,503]) monitor.observe(status);
  assert.deepEqual(monitor.snapshot(),{requests:7,unauthorized:1,forbidden:1,conflicts:1,limited:1,errors:2});
  const snapshot=monitor.drain();
  assert.equal(snapshot.requests,7);
  assert.equal(monitor.snapshot().requests,0);
  assert.throws(()=>{snapshot.requests=0;},TypeError);
});
