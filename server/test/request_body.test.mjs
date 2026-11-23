import test from 'node:test';
import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { readBody } from '../src/request_body.mjs';

test('readBody preserves multi-byte UTF-8 split across chunks', async () => {
  const text = JSON.stringify({ description: 'دين بالعربية', amount: '75.50' });
  const bytes = Buffer.from(text, 'utf8');
  const cut = bytes.indexOf(Buffer.from('دين')) + 1;
  const body = await readBody(Readable.from([bytes.subarray(0, cut), bytes.subarray(cut)]), 4096);
  assert.equal(body, text);
  assert.equal(JSON.parse(body).description, 'دين بالعربية');
});

test('readBody enforces the byte limit and rejects oversized bodies', async () => {
  await assert.rejects(readBody(Readable.from([Buffer.from('abc')]), 2),
    e => e.status === 413);
  assert.equal(await readBody(Readable.from([Buffer.from('abc')]), 3), 'abc');
});
