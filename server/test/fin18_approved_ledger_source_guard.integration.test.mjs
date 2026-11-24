import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Fin08Store } from '../src/store.mjs';

const databaseUrl = process.env.FIN08_TEST_DATABASE_URL;

test('FIN18 DB rejects forged approved ledger rows and permits the real approved posting',
  {skip: !databaseUrl}, async () => {
    const { Pool } = await import('pg');
    const pool = new Pool({connectionString: databaseUrl});
    const marker = randomUUID().slice(0, 8);
    const store = new Fin08Store(pool, {
      cursorSecret: 'fin18-source-integrity-synthetic-testing-secret',
    });
    const merchant = {id: 'fin18-merchant-' + marker, role: 'merchant'};
    const customer = {id: 'fin18-customer-' + marker, role: 'customer'};
    const identity = {id: 'fin18-identity', role: 'identity_service'};
    const phone = '+96777' + String(Math.floor(Math.random() * 10000000)).padStart(7, '0');
    const key = name => 'fin18-' + marker + '-' + name;
    try {
      await store.onboardMerchant(identity, {
        merchant_id: merchant.id,
        verified_display_name: 'Synthetic integrity merchant',
      });
      const contact = await store.createContact(merchant, {
        name: 'Synthetic ledger customer',
        phone,
      });
      await store.verifyPhone(identity, {
        customer_id: customer.id,
        phone,
        proof_reference: key('phone-proof'),
      });
      const relationship = (await store.listCustomerRelationships(customer, {})).items[0];
      assert.ok(relationship?.relationship_id);
      await store.decideRelationship(customer, relationship.relationship_id,
        {decision: 'accept'});

      const pending = (await store.createClaim(merchant, {
        contact_id: contact.id,
        amount: '100',
        currency: 'YER',
        type: 'debt',
      }, key('pending-claim'))).claim;
      const sql = `INSERT INTO financial_movements
        (id,source_claim_id,relationship_id,merchant_id,customer_id,amount,currency,type)
        VALUES($1,$2,$3,$4,$5,$6,$7,$8)`;
      const forged = [
        randomUUID(), pending.id, relationship.relationship_id,
        merchant.id, customer.id, '999', 'SAR', 'debt',
      ];
      await assert.rejects(pool.query(sql, forged), error =>
        error.code === '23514' && /authorized source/.test(error.message));
      let rows = await pool.query('SELECT id FROM financial_movements WHERE source_claim_id=$1',
        [pending.id]);
      assert.equal(rows.rowCount, 0,
        'Unapproved/forged source cannot create an approved ledger row');

      await store.decideClaim(customer, pending.id, {decision: 'accept'});
      rows = await pool.query(`SELECT amount::text AS amount,currency,type,merchant_id,customer_id
        FROM financial_movements WHERE source_claim_id=$1`, [pending.id]);
      assert.equal(rows.rowCount, 1, 'The real valid two-party approved source must still post');
      assert.equal(rows.rows[0].amount, '100.0000');
      assert.equal(rows.rows[0].currency, 'YER');
      assert.equal(rows.rows[0].merchant_id, merchant.id);
      assert.equal(rows.rows[0].customer_id, customer.id);

      // Isolate every provenance field on an APPROVED source. BEFORE INSERT
      // must reject the mutation before the unique-source constraint masks it.
      const approvedFacts = [randomUUID(), pending.id, relationship.relationship_id,
        merchant.id, customer.id, '100', 'YER', 'debt'];
      for (const [field, index, value] of [
        ['amount', 5, '100.0001'], ['currency', 6, 'SAR'],
        ['merchant', 3, 'forged-merchant'], ['customer', 4, 'forged-customer'],
        ['relationship', 2, randomUUID()], ['type', 7, 'payment'],
      ]) {
        const mutated = [...approvedFacts];
        mutated[0] = randomUUID();
        mutated[index] = value;
        await assert.rejects(pool.query(sql, mutated),
          error => error.code === '23514' && /authorized source/.test(error.message),
          `FIN18 must reject independently mismatched ${field}`);
      }

      // Test both source branches with a genuinely bilateral payment.
      const payment = await store.ledger.createOperation(customer,
        relationship.relationship_id,
        {type: 'payment', amount: '25.0001', currency: 'USD'}, key('payment'));
      await store.ledger.decideOperation(merchant, relationship.relationship_id,
        payment.operation_id, {decision: 'accept'});
      const operationSql = sql.replace('source_claim_id', 'source_operation_id');
      const operationFacts = [randomUUID(), payment.operation_id,
        relationship.relationship_id, merchant.id, customer.id, '25.0001', 'USD', 'payment'];
      for (const [field, index, value] of [
        ['amount', 5, '25.0002'], ['currency', 6, 'YER'],
        ['merchant', 3, 'forged-merchant'], ['customer', 4, 'forged-customer'],
        ['relationship', 2, randomUUID()], ['type', 7, 'debt'],
      ]) {
        const mutated = [...operationFacts];
        mutated[0] = randomUUID();
        mutated[index] = value;
        await assert.rejects(pool.query(operationSql, mutated),
          error => error.code === '23514',
          `FIN18 operation must reject independently mismatched ${field}`);
      }

      // Another unapproved claim cannot be spoofed, even with the right
      // amount and currency but the wrong customer.
      const second = (await store.createClaim(merchant, {
        contact_id: contact.id,
        amount: '1',
        currency: 'USD',
        type: 'debt',
      }, key('unapproved-source'))).claim;
      await assert.rejects(pool.query(sql, [
        randomUUID(), second.id, relationship.relationship_id,
        merchant.id, 'attacker-account', '1', 'USD', 'debt',
      ]), error => error.code === '23514');
    } finally {
      await pool.end();
    }
  });
