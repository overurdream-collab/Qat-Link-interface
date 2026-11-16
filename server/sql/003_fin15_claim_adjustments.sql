-- FIN-15 | Applies after 001_FIN08.sql and 002_FIN13_unified_ledger.sql.
-- The original claim amount, currency, historical date and accounting entries
-- are NEVER overwritten. An accepted adjustment supersedes only a PENDING claim.
BEGIN;
ALTER TABLE merchant_claims
  ADD COLUMN IF NOT EXISTS source_claim_id uuid REFERENCES merchant_claims(id),
  ADD COLUMN IF NOT EXISTS superseded_by_claim_id uuid REFERENCES merchant_claims(id);
CREATE UNIQUE INDEX IF NOT EXISTS merchant_claims_single_replacement_idx
  ON merchant_claims(source_claim_id) WHERE source_claim_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS merchant_claims_superseded_idx
  ON merchant_claims(superseded_by_claim_id)
  WHERE superseded_by_claim_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS customer_claim_adjustment_requests (
  id uuid PRIMARY KEY,
  claim_id uuid NOT NULL REFERENCES merchant_claims(id),
  merchant_id text NOT NULL,
  customer_id text NOT NULL,
  original_amount numeric(20,4) NOT NULL CHECK(original_amount>0),
  proposed_amount numeric(20,4) NOT NULL CHECK(proposed_amount>0),
  reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 2 AND 500),
  status text NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','accepted','rejected')),
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  decided_at timestamptz,
  decided_by text,
  CHECK(original_amount<>proposed_amount),
  CHECK(
    (status='pending' AND decided_at IS NULL AND decided_by IS NULL) OR
    (status<>'pending' AND decided_at IS NOT NULL AND decided_by IS NOT NULL)
  )
);
CREATE UNIQUE INDEX IF NOT EXISTS customer_claim_adjustment_one_pending_idx
  ON customer_claim_adjustment_requests(claim_id) WHERE status='pending';
CREATE INDEX IF NOT EXISTS customer_claim_adjustment_merchant_idx
  ON customer_claim_adjustment_requests(merchant_id,status,requested_at DESC,id DESC);

-- An approved ledger movement must never be undone by changing source claims.
-- The existing FIN13 financial_movements UPDATE/DELETE trigger remains in force.
COMMIT;
