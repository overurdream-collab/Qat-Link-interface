-- FIN25: SMS Gateway public-key registration. Apply after migrations 001-007.
-- Never store Android Keystore private keys or plaintext OTP here.
BEGIN;
CREATE TABLE IF NOT EXISTS sms_gateway_devices (
  device_id uuid PRIMARY KEY,
  display_name text NOT NULL CHECK (length(trim(display_name)) BETWEEN 1 AND 100),
  public_key_spki_pem text NOT NULL CHECK (length(public_key_spki_pem) BETWEEN 100 AND 4096),
  key_fingerprint_sha256 char(64) NOT NULL UNIQUE CHECK (key_fingerprint_sha256 ~ '^[a-f0-9]{64}$'),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','suspended','revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz,
  revoked_at timestamptz,
  last_seen_at timestamptz,
  CHECK ((status <> 'revoked') OR revoked_at IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS sms_gateway_device_nonces (
  device_id uuid NOT NULL REFERENCES sms_gateway_devices(device_id),
  nonce_hash char(64) NOT NULL CHECK (nonce_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  PRIMARY KEY(device_id,nonce_hash),
  CHECK (expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS sms_gateway_nonces_expiry_idx ON sms_gateway_device_nonces(expires_at);
COMMIT;
