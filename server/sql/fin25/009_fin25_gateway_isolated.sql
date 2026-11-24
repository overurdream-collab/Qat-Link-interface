-- FIN25 isolated gateway schema; never alter financial migrations 001-008.
BEGIN;
CREATE TABLE IF NOT EXISTS fin25_gateway_devices (
 device_id uuid PRIMARY KEY, public_key_spki_pem text NOT NULL,
 fingerprint_sha256 char(64) NOT NULL UNIQUE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','proved','active','suspended','revoked')),
 proved_at timestamptz, activated_at timestamptz, last_seen_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS fin25_gateway_challenges (
 device_id uuid PRIMARY KEY REFERENCES fin25_gateway_devices(device_id),
 challenge_hash char(64) NOT NULL, expires_at timestamptz NOT NULL,
 consumed_at timestamptz
);
CREATE TABLE IF NOT EXISTS fin25_gateway_nonces (
 device_id uuid NOT NULL REFERENCES fin25_gateway_devices(device_id),
 nonce_hash char(64) NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(device_id,nonce_hash)
);
CREATE INDEX IF NOT EXISTS fin25_gateway_nonces_time ON fin25_gateway_nonces(created_at);
CREATE TABLE IF NOT EXISTS fin25_gateway_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, device_id uuid NOT NULL,
 action text NOT NULL, at timestamptz NOT NULL DEFAULT now()
);
COMMIT;
