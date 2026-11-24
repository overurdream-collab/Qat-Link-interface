import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

const url = process.env.FIN08_TEST_DATABASE_URL;
test('runtime audit rejects NOINHERIT membership allowing SET ROLE to ledger owner',
  {skip: !url}, async () => {
    const { Pool } = await import('pg');
    const pool = new Pool({connectionString: url});
    const c = await pool.connect();
    const role = 'fin18_probe_' + randomUUID().replaceAll('-', '');
    const audit = await readFile(new URL('../sql/audit_fin18_runtime_role.sql', import.meta.url), 'utf8');
    try {
      // All role creation/grants roll back; never touch existing identities.
      await c.query('BEGIN');
      const owner = (await c.query("SELECT pg_get_userbyid(relowner) AS name FROM pg_class WHERE oid='public.financial_movements'::regclass")).rows[0].name;
      const quotedOwner = '"' + owner.replaceAll('"', '""') + '"';
      await c.query(`CREATE ROLE ${role} NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`);
      await c.query(`GRANT ${quotedOwner} TO ${role}`);
      await c.query(`GRANT USAGE ON SCHEMA public TO ${role}`);
      await c.query(`SET LOCAL ROLE ${role}`);
      assert.equal((await c.query("SELECT has_table_privilege(current_user,'public.financial_movements','TRUNCATE') AS permitted")).rows[0].permitted,
        false, 'NOINHERIT hides effective owner privilege from the old audit');
      await assert.rejects(c.query(audit),
        error => error.code === 'P0001' && /member of table owner/.test(error.message));
    } finally {
      await c.query('ROLLBACK');
      c.release();
      await pool.end();
    }
  });
