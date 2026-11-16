-- FIN-13 | Additive migration over 001_fin08.sql; PostgreSQL 16+.
-- The original approved movement rows and claim IDs remain immutable and valid.
-- Apply ONLY after 001, once, via a privileged migrator. Runtime API has no DDL rights.
BEGIN;

ALTER TABLE merchant_claims
  ADD COLUMN IF NOT EXISTS operation_type text NOT NULL DEFAULT 'debt'
    CHECK (operation_type IN ('debt','payment')),
  ADD COLUMN IF NOT EXISTS occurred_at timestamptz;
UPDATE merchant_claims SET occurred_at=created_at WHERE occurred_at IS NULL;
ALTER TABLE merchant_claims ALTER COLUMN occurred_at SET DEFAULT now(),
  ALTER COLUMN occurred_at SET NOT NULL;

ALTER TABLE financial_movements DROP CONSTRAINT IF EXISTS financial_movements_type_check;
ALTER TABLE financial_movements
  ADD CONSTRAINT financial_movements_type_check CHECK (type IN ('debt','payment'));
ALTER TABLE financial_movements
  ADD COLUMN IF NOT EXISTS source_operation_id uuid UNIQUE,
  ADD COLUMN IF NOT EXISTS reversal_of_movement_id uuid REFERENCES financial_movements(id);
ALTER TABLE financial_movements ALTER COLUMN source_claim_id DROP NOT NULL;
ALTER TABLE financial_movements
  ADD CONSTRAINT financial_movement_exactly_one_source
    CHECK ((source_claim_id IS NOT NULL) <> (source_operation_id IS NOT NULL)),
  ADD CONSTRAINT financial_movement_reversal_distinct
    CHECK (reversal_of_movement_id IS NULL OR reversal_of_movement_id <> id);
CREATE UNIQUE INDEX IF NOT EXISTS financial_movements_reversal_once_idx
  ON financial_movements(reversal_of_movement_id)
  WHERE reversal_of_movement_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS financial_movements_relationship_currency_date_idx
  ON financial_movements(relationship_id,currency,posted_at,id);

-- Requests remain separate from the authoritative APPROVED financial_movements.
-- Each participant's declaration is inherent in created_by / created_by_role.
CREATE TABLE IF NOT EXISTS relationship_operations (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL REFERENCES merchant_relationships(id),
  merchant_id text NOT NULL,
  customer_id text NOT NULL,
  created_by text NOT NULL,
  created_by_role text NOT NULL CHECK (created_by_role IN ('merchant','customer')),
  operation_type text NOT NULL CHECK (operation_type IN ('debt','payment')),
  amount numeric(20,4) NOT NULL CHECK (amount > 0),
  currency text NOT NULL CHECK (currency IN ('YER','SAR','USD')),
  description text CHECK (description IS NULL OR length(description) <= 500),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  decided_at timestamptz,
  decided_by text,
  approval_method text NOT NULL DEFAULT 'manual'
    CHECK (approval_method IN ('manual','delegated_policy')),
  auto_policy_version integer,
  reversal_of_movement_id uuid REFERENCES financial_movements(id),
  idempotency_key text NOT NULL,
  request_digest char(64) NOT NULL,
  UNIQUE(created_by,idempotency_key),
  UNIQUE(relationship_id,id)
);
ALTER TABLE financial_movements
  ADD CONSTRAINT financial_movements_source_operation_fk
    FOREIGN KEY (source_operation_id) REFERENCES relationship_operations(id);
CREATE INDEX IF NOT EXISTS relationship_operations_inbox_idx
  ON relationship_operations(relationship_id,created_at DESC,id DESC);

-- Never permit two simultaneously live reversals of the same approved movement.
CREATE UNIQUE INDEX IF NOT EXISTS relationship_operations_live_reversal_idx
  ON relationship_operations(reversal_of_movement_id)
  WHERE reversal_of_movement_id IS NOT NULL AND status <> 'rejected';

CREATE TABLE IF NOT EXISTS relationship_auto_approval_policies (
  relationship_id uuid PRIMARY KEY REFERENCES merchant_relationships(id),
  enabled boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
  effective_at timestamptz,
  disabled_at timestamptz,
  updated_by text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS relationship_policy_events (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL REFERENCES merchant_relationships(id),
  version integer NOT NULL,
  enabled boolean NOT NULL,
  actor_id text NOT NULL,
  happened_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(relationship_id,version)
);

-- FIN-13: the approved ledger is append-only. Corrections post new reversing
-- entries, preserving source operations and original approval history.
CREATE OR REPLACE FUNCTION fin13_immutable_approved_movement()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Approved ledger rows are immutable; post an audited reversal';
END;$$;
DROP TRIGGER IF EXISTS fin13_approved_movement_immutable ON financial_movements;
CREATE TRIGGER fin13_approved_movement_immutable
  BEFORE UPDATE OR DELETE ON financial_movements
  FOR EACH ROW EXECUTE FUNCTION fin13_immutable_approved_movement();
COMMIT;
