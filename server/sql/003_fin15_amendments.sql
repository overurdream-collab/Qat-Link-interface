-- FIN-15 | additive, reversible-by-backup schema migration after 001 + 002.
-- Any approved financial movement remains immutable.
BEGIN;

ALTER TABLE merchant_claims
  ADD COLUMN IF NOT EXISTS superseded_by_claim_id uuid REFERENCES merchant_claims(id);
CREATE INDEX IF NOT EXISTS merchant_claims_superseded_lookup
  ON merchant_claims(superseded_by_claim_id)
  WHERE superseded_by_claim_id IS NOT NULL;

ALTER TABLE relationship_operations
  DROP CONSTRAINT IF EXISTS relationship_operations_status_check;
ALTER TABLE relationship_operations
  ADD CONSTRAINT relationship_operations_status_check
    CHECK (status IN ('pending','approved','rejected','superseded'));
ALTER TABLE relationship_operations
  ADD COLUMN IF NOT EXISTS replaces_operation_id uuid REFERENCES relationship_operations(id);
CREATE UNIQUE INDEX IF NOT EXISTS relationship_operations_replaces_once
  ON relationship_operations(replaces_operation_id)
  WHERE replaces_operation_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS financial_amendment_requests (
  id uuid PRIMARY KEY,
  original_claim_id uuid REFERENCES merchant_claims(id),
  original_operation_id uuid REFERENCES relationship_operations(id),
  merchant_id text NOT NULL REFERENCES merchant_profiles(merchant_id),
  customer_id text NOT NULL,
  original_amount numeric(20,4) NOT NULL CHECK(original_amount > 0),
  proposed_amount numeric(20,4) NOT NULL CHECK(proposed_amount > 0),
  currency text NOT NULL CHECK (currency IN ('YER','SAR','USD')),
  reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 3 AND 500),
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  status text NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','accepted','rejected')),
  decided_at timestamptz,
  decided_by text,
  replacement_claim_id uuid REFERENCES merchant_claims(id),
  replacement_operation_id uuid REFERENCES relationship_operations(id),
  request_key text NOT NULL,
  request_digest char(64) NOT NULL,
  UNIQUE(customer_id,request_key),
  CONSTRAINT fin15_one_original CHECK(
    (original_claim_id IS NOT NULL) <> (original_operation_id IS NOT NULL)),
  CONSTRAINT fin15_mutually_exclusive_replacements CHECK(
    NOT (replacement_claim_id IS NOT NULL AND replacement_operation_id IS NOT NULL)),
  CONSTRAINT fin15_valid_completion CHECK(
    (status='pending' AND decided_at IS NULL AND decided_by IS NULL
       AND replacement_claim_id IS NULL AND replacement_operation_id IS NULL)
    OR (status='rejected' AND decided_at IS NOT NULL AND decided_by IS NOT NULL
       AND replacement_claim_id IS NULL AND replacement_operation_id IS NULL)
    OR (status='accepted' AND decided_at IS NOT NULL AND decided_by IS NOT NULL
       AND ((original_claim_id IS NOT NULL AND replacement_claim_id IS NOT NULL
         AND replacement_operation_id IS NULL)
         OR (original_operation_id IS NOT NULL AND replacement_operation_id IS NOT NULL
         AND replacement_claim_id IS NULL)))
  )
);
-- Only one active proposal per source. A rejected proposal may be followed
-- by a new explicitly initiated customer proposal; accepted sources are superseded.
CREATE UNIQUE INDEX IF NOT EXISTS fin15_active_claim_amendment
  ON financial_amendment_requests(original_claim_id)
  WHERE original_claim_id IS NOT NULL AND status='pending';
CREATE UNIQUE INDEX IF NOT EXISTS fin15_active_operation_amendment
  ON financial_amendment_requests(original_operation_id)
  WHERE original_operation_id IS NOT NULL AND status='pending';
CREATE INDEX IF NOT EXISTS fin15_merchant_amendments
  ON financial_amendment_requests(merchant_id,requested_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS fin15_customer_amendments
  ON financial_amendment_requests(customer_id,requested_at DESC,id DESC);

COMMIT;
