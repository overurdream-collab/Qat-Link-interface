-- P0 identity refresh/revocation registry. Apply ONLY to the isolated identity DB.
-- Access tokens carry a session id (`sid`) and are rejected once revoked.
-- Refresh tokens are stored only as SHA-256 hashes; raw values never reach disk.
CREATE TABLE IF NOT EXISTS identity_sessions (
  id uuid PRIMARY KEY,
  subject uuid NOT NULL REFERENCES identity_accounts(subject) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('merchant','customer')),
  refresh_hash text NOT NULL UNIQUE CHECK (refresh_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  rotated_at timestamptz,
  CHECK (expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS identity_sessions_active_subject
  ON identity_sessions(subject) WHERE revoked_at IS NULL;
