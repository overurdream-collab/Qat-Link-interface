-- FIN-17 | Auditable payment-to-debt allocation and unallocated customer credit.
-- Additive migration after 001..004. Approved financial movements remain unchanged.
BEGIN;

CREATE TABLE IF NOT EXISTS financial_payment_allocation_requests (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL REFERENCES merchant_relationships(id),
  merchant_id text NOT NULL REFERENCES merchant_profiles(merchant_id),
  customer_id text NOT NULL,
  action text NOT NULL CHECK (action IN ('allocate','release')),
  payment_movement_id uuid NOT NULL REFERENCES financial_movements(id),
  debt_movement_id uuid NOT NULL REFERENCES financial_movements(id),
  allocation_id uuid REFERENCES financial_payment_allocation_requests(id),
  amount numeric(20,4) NOT NULL CHECK (amount > 0),
  requested_by text NOT NULL,
  requested_by_role text NOT NULL CHECK (requested_by_role IN ('merchant','customer')),
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  decided_by text,
  decided_at timestamptz,
  idempotency_key text NOT NULL,
  request_digest char(64) NOT NULL,
  UNIQUE(requested_by,idempotency_key),
  CHECK ((action='allocate' AND allocation_id IS NULL) OR
         (action='release' AND allocation_id IS NOT NULL)),
  CHECK ((status='pending' AND decided_by IS NULL AND decided_at IS NULL) OR
         (status IN ('approved','rejected') AND decided_by IS NOT NULL AND decided_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS fin17_allocation_requests_inbox
  ON financial_payment_allocation_requests(relationship_id,status,requested_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS fin17_allocation_requests_payment
  ON financial_payment_allocation_requests(payment_movement_id,status,requested_at DESC);

CREATE TABLE IF NOT EXISTS financial_payment_allocation_entries (
  id uuid PRIMARY KEY,
  request_id uuid NOT NULL UNIQUE REFERENCES financial_payment_allocation_requests(id),
  allocation_id uuid NOT NULL REFERENCES financial_payment_allocation_requests(id),
  relationship_id uuid NOT NULL REFERENCES merchant_relationships(id),
  payment_movement_id uuid NOT NULL REFERENCES financial_movements(id),
  debt_movement_id uuid NOT NULL REFERENCES financial_movements(id),
  action text NOT NULL CHECK (action IN ('allocate','release')),
  amount numeric(20,4) NOT NULL CHECK (amount > 0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS fin17_allocation_entries_payment
  ON financial_payment_allocation_entries(payment_movement_id,created_at,id);
CREATE INDEX IF NOT EXISTS fin17_allocation_entries_debt
  ON financial_payment_allocation_entries(debt_movement_id,created_at,id);
CREATE INDEX IF NOT EXISTS fin17_allocation_entries_bucket
  ON financial_payment_allocation_entries(allocation_id,created_at,id);

CREATE OR REPLACE FUNCTION fin17_immutable_allocation_entry()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Allocation history is immutable; submit an approved release request';
END;$$;
DROP TRIGGER IF EXISTS fin17_allocation_entry_immutable ON financial_payment_allocation_entries;
CREATE TRIGGER fin17_allocation_entry_immutable
  BEFORE UPDATE OR DELETE ON financial_payment_allocation_entries
  FOR EACH ROW EXECUTE FUNCTION fin17_immutable_allocation_entry();

CREATE OR REPLACE FUNCTION fin17_allocation_request_transition()
RETURNS trigger LANGUAGE plpgsql AS $
BEGIN
  IF TG_OP='DELETE' THEN
    RAISE EXCEPTION 'Allocation request history is immutable';
  END IF;
  IF OLD.status <> 'pending' OR NEW.status NOT IN ('approved','rejected')
     OR NEW.decided_by IS NULL OR NEW.decided_at IS NULL THEN
    RAISE EXCEPTION 'Allocation requests allow one pending-to-final decision only';
  END IF;
  IF ROW(NEW.id,NEW.relationship_id,NEW.merchant_id,NEW.customer_id,NEW.action,
         NEW.payment_movement_id,NEW.debt_movement_id,NEW.allocation_id,NEW.amount,
         NEW.requested_by,NEW.requested_by_role,NEW.requested_at,NEW.idempotency_key,
         NEW.request_digest)
     IS DISTINCT FROM
     ROW(OLD.id,OLD.relationship_id,OLD.merchant_id,OLD.customer_id,OLD.action,
         OLD.payment_movement_id,OLD.debt_movement_id,OLD.allocation_id,OLD.amount,
         OLD.requested_by,OLD.requested_by_role,OLD.requested_at,OLD.idempotency_key,
         OLD.request_digest) THEN
    RAISE EXCEPTION 'Allocation request facts are immutable';
  END IF;
  RETURN NEW;
END;$;
DROP TRIGGER IF EXISTS fin17_allocation_request_transition ON financial_payment_allocation_requests;
CREATE TRIGGER fin17_allocation_request_transition
  BEFORE UPDATE OR DELETE ON financial_payment_allocation_requests
  FOR EACH ROW EXECUTE FUNCTION fin17_allocation_request_transition();

COMMIT;
