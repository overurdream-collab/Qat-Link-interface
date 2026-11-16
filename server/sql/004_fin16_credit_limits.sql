-- FIN-16 | credit policy per approved merchant/customer relationship and currency.
-- Approved financial movements remain the sole financial authority.
-- Run after 001,002,003 using a privileged migration role. No existing
-- financial entries or consent events are rewritten.
BEGIN;

CREATE TABLE IF NOT EXISTS relationship_credit_limits (
  relationship_id uuid NOT NULL REFERENCES merchant_relationships(id),
  currency text NOT NULL CHECK (currency IN ('YER','SAR','USD')),
  limit_amount numeric(20,4) NOT NULL CHECK(limit_amount >= 0),
  mode text NOT NULL CHECK (mode IN ('warn','block')),
  enabled boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  updated_by text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY(relationship_id,currency)
);
CREATE TABLE IF NOT EXISTS relationship_credit_limit_events (
  id uuid PRIMARY KEY,
  relationship_id uuid NOT NULL REFERENCES merchant_relationships(id),
  currency text NOT NULL CHECK (currency IN ('YER','SAR','USD')),
  actor_id text NOT NULL,
  action text NOT NULL CHECK(action IN ('set','disable')),
  version integer NOT NULL CHECK(version > 0),
  previous_amount numeric(20,4),
  previous_mode text,
  limit_amount numeric(20,4),
  mode text,
  happened_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT fin16_event_set_valid CHECK (
    (action='set' AND limit_amount IS NOT NULL AND mode IN ('warn','block'))
    OR (action='disable' AND limit_amount IS NULL AND mode IS NULL)
  )
);
CREATE INDEX IF NOT EXISTS fin16_credit_limit_history_idx
  ON relationship_credit_limit_events(relationship_id,currency,happened_at DESC,id DESC);
COMMIT;
