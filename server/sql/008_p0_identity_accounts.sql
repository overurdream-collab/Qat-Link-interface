-- P0 identity registry. Apply ONLY to isolated identity PostgreSQL DB.
-- This is a new, separate schema; do not apply to a FIN25 SMS or FIN08 ledger DB.
-- A phone becomes an identity only after server-to-server one-time OTP proof.
CREATE TABLE IF NOT EXISTS identity_accounts (
  subject uuid PRIMARY KEY,
  phone text NOT NULL UNIQUE CHECK (phone ~ '^[+]967[0-9]{9}$'),
  role text NOT NULL CHECK (role IN ('merchant','customer')),
  finance_proof_reference uuid NOT NULL UNIQUE,
  finance_provisioned_at timestamptz,
  display_name text CHECK (
    display_name IS NULL OR length(trim(display_name)) BETWEEN 2 AND 160
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_login_at timestamptz,
  CHECK (role <> 'merchant' OR display_name IS NOT NULL)
);
-- Separate least-privilege runtime role recommended.
-- Never store OTP values, proof tokens, PINs, private keys, or SMS text here.
