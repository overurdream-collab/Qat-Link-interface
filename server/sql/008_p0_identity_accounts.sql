-- P0: isolated identity registry. Apply with a migration role only.
-- User's phone is bound by a one-time FIN25 OTP proof redeemed server-to-server.
CREATE TABLE IF NOT EXISTS identity_accounts (
  subject uuid PRIMARY KEY,
  phone text NOT NULL UNIQUE CHECK (phone ~ '^\\+967[0-9]{9}$'),
  role text NOT NULL CHECK (role IN ('merchant','customer')),
  display_name text CHECK (display_name IS NULL OR length(trim(display_name)) BETWEEN 2 AND 160),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_login_at timestamptz,
  CHECK (role <> 'merchant' OR display_name IS NOT NULL)
);
-- Separate least-privilege identity database recommended, not the financial DB.
-- No OTP, proof token, PIN, private key or SMS body is persisted here.
