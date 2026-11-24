-- Synthetic isolated test databases only. No row contents in output.
-- Compare every public table exactly: ledger, approvals, relationships,
-- allocations, policy events and audit events. Canonical order is deterministic.
\set ON_ERROR_STOP on
SET timezone = 'UTC';
SET extra_float_digits = 3;
SELECT format(
  'SELECT %L AS table_name, count(*) AS rows, md5(COALESCE(string_agg(row_to_json(t)::text, E''\n'' ORDER BY row_to_json(t)::text), '''')) AS content_hash FROM %I.%I t;',
  tablename, schemaname, tablename)
FROM pg_tables WHERE schemaname='public' ORDER BY tablename
\gexec

-- Independent signed ledger reconciliation: no JavaScript float/cached balance.
SELECT relationship_id, currency,
       SUM(CASE WHEN type='debt' THEN amount ELSE -amount END)::text AS balance,
       COUNT(*) AS approved_entries
FROM financial_movements WHERE status='approved'
GROUP BY relationship_id,currency ORDER BY relationship_id,currency;
