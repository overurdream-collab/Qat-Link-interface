import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const url = process.env.FIN08_TEST_DATABASE_URL;
test('PostgreSQL rejects NaN amounts at the database boundary without changing exact valid values',
  {skip: !url}, async () => {
    const { Pool } = await import('pg');
    const pool = new Pool({connectionString: url});
    const c = await pool.connect();
    const marker = randomUUID();
    try {
      await c.query('BEGIN');
      assert.equal((await c.query("SELECT 'NaN'::numeric(20,4)>0 AS bypass")).rows[0].bypass,
        true, 'The regression reproduces the PostgreSQL >0 CHECK bypass');
      const constraints = await c.query("SELECT conname,convalidated FROM pg_constraint WHERE conname LIKE 'fin_finite_%'");
      assert.equal(constraints.rowCount, 10);
      assert.ok(constraints.rows.every(x => x.convalidated));
      await c.query('INSERT INTO merchant_profiles(merchant_id,verified_display_name) VALUES($1,$2)',
        [marker, 'Synthetic finite regression']);
      const contact = randomUUID();
      await c.query('INSERT INTO merchant_contacts(id,merchant_id,display_name,normalized_phone) VALUES($1,$2,$3,$4)',
        [contact, marker, 'Synthetic customer', '+967771234567']);
      const insert = `INSERT INTO merchant_claims(id,merchant_id,contact_id,amount,currency,idempotency_key,request_digest)
        VALUES($1,$2,$3,$4,'YER',$5,$6)`;
      await c.query('SAVEPOINT finite_check');
      await assert.rejects(c.query(insert, [randomUUID(),marker,contact,'NaN',marker,'0'.repeat(64)]),
        error => error.code === '23514' && error.constraint === 'fin_finite_claim_amount');
      await c.query('ROLLBACK TO SAVEPOINT finite_check');
      const id = randomUUID();
      await c.query(insert, [id,marker,contact,'9999999999999999.9999',marker,'0'.repeat(64)]);
      assert.equal((await c.query('SELECT amount::text FROM merchant_claims WHERE id=$1',[id])).rows[0].amount,
        '9999999999999999.9999');
      await assert.rejects(c.query(`UPDATE merchant_claims SET amount='NaN'::numeric WHERE id=$1`, [id]),
        error => error.code === '23514' && error.constraint === 'fin_finite_claim_amount');
    } finally {
      await c.query('ROLLBACK');
      c.release();
      await pool.end();
    }
  });
