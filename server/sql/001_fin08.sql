-- FIN-08 | PostgreSQL 16+. Apply once as the database owner using psql -v ON_ERROR_STOP=1.
-- The database role used by the public API MUST NOT have CREATE/ALTER/DROP privileges.
-- Accounts and merchants are represented by authenticated external subject identifiers.
CREATE TABLE IF NOT EXISTS merchant_profiles (
  merchant_id text PRIMARY KEY,
  verified_display_name text NOT NULL CHECK (length(trim(verified_display_name)) BETWEEN 2 AND 160)
);
CREATE TABLE IF NOT EXISTS merchant_contacts (
  id uuid PRIMARY KEY,
  merchant_id text NOT NULL REFERENCES merchant_profiles(merchant_id),
  display_name text NOT NULL CHECK (length(trim(display_name)) BETWEEN 2 AND 160),
  normalized_phone text NOT NULL CHECK (normalized_phone ~ '^\+[1-9][0-9]{8,14}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, id),
  UNIQUE (merchant_id, normalized_phone)
);
CREATE INDEX IF NOT EXISTS merchant_contacts_phone_idx ON merchant_contacts(normalized_phone);
CREATE TABLE IF NOT EXISTS merchant_claims (
  id uuid PRIMARY KEY,
  merchant_id text NOT NULL,
  contact_id uuid NOT NULL,
  amount numeric(20,4) NOT NULL CHECK (amount > 0),
  currency text NOT NULL CHECK (currency IN ('YER','SAR','USD')),
  description text CHECK (description IS NULL OR length(description) <= 500),
  idempotency_key text NOT NULL,
  request_digest char(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, id),
  UNIQUE (merchant_id, idempotency_key),
  FOREIGN KEY (merchant_id, contact_id) REFERENCES merchant_contacts(merchant_id, id)
);
CREATE INDEX IF NOT EXISTS merchant_claims_contact_idx ON merchant_claims(merchant_id,contact_id,created_at DESC,id DESC);
-- Supplied only by an authenticated, verified identity-service event (never by customer forms).
-- Keep prior proofs and revoke explicitly when a phone changes owner; conflicts fail closed.
CREATE TABLE IF NOT EXISTS customer_phone_evidence (
  id uuid PRIMARY KEY,
  customer_id text NOT NULL,
  normalized_phone text NOT NULL CHECK (normalized_phone ~ '^\+[1-9][0-9]{8,14}$'),
  proof_reference text NOT NULL UNIQUE,
  verified_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  CHECK (revoked_at IS NULL OR revoked_at >= verified_at)
);
CREATE INDEX IF NOT EXISTS customer_evidence_phone_idx ON customer_phone_evidence(normalized_phone) WHERE revoked_at IS NULL;
CREATE TABLE IF NOT EXISTS verified_contact_links (
  merchant_id text NOT NULL,
  contact_id uuid NOT NULL,
  customer_id text NOT NULL,
  proof_reference text NOT NULL REFERENCES customer_phone_evidence(proof_reference),
  linked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (merchant_id, contact_id),
  FOREIGN KEY (merchant_id, contact_id) REFERENCES merchant_contacts(merchant_id,id)
);
CREATE INDEX IF NOT EXISTS verified_contact_links_customer_idx ON verified_contact_links(customer_id);
CREATE TABLE IF NOT EXISTS merchant_relationships (
  id uuid PRIMARY KEY,
  merchant_id text NOT NULL REFERENCES merchant_profiles(merchant_id),
  customer_id text NOT NULL,
  contact_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  UNIQUE (merchant_id, customer_id),
  FOREIGN KEY (merchant_id, contact_id) REFERENCES merchant_contacts(merchant_id,id)
);
CREATE TABLE IF NOT EXISTS customer_claim_decisions (
  claim_id uuid PRIMARY KEY REFERENCES merchant_claims(id),
  merchant_id text NOT NULL,
  customer_id text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('accept','reject')),
  decided_at timestamptz NOT NULL DEFAULT now()
);
-- This table contains APPROVED DEBTS sourced from pre-registration merchant claims only.
-- Payments and ordinary debt movements belong to the wider ledger integration.
CREATE TABLE IF NOT EXISTS financial_movements (
  id uuid PRIMARY KEY,
  source_claim_id uuid NOT NULL UNIQUE REFERENCES merchant_claims(id),
  relationship_id uuid NOT NULL REFERENCES merchant_relationships(id),
  merchant_id text NOT NULL,
  customer_id text NOT NULL,
  amount numeric(20,4) NOT NULL CHECK (amount > 0),
  currency text NOT NULL CHECK (currency IN ('YER','SAR','USD')),
  type text NOT NULL DEFAULT 'debt' CHECK (type = 'debt'),
  status text NOT NULL DEFAULT 'approved' CHECK (status = 'approved'),
  posted_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS fin08_audit_events (
  id uuid PRIMARY KEY,
  actor_id text NOT NULL,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  action text NOT NULL,
  event_time timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS fin08_audit_entity_idx ON fin08_audit_events(entity_type,entity_id,event_time DESC);
-- Production access control is enforced by the API's server-authenticated identity
-- and the scoped SQL WHERE clauses, never by caller-supplied merchant/customer IDs.
-- Deploy using a private DB, least-privilege application role and TLS.