-- Local SMS OTP queue. Apply separately with a migration role; never use the API role for DDL.
BEGIN;
CREATE TABLE IF NOT EXISTS otp_challenges (
 id uuid PRIMARY KEY, phone text NOT NULL, code_digest text NOT NULL,
 expires_at timestamptz NOT NULL, resend_after timestamptz NOT NULL,
 attempts integer NOT NULL DEFAULT 0, consumed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT otp_attempts_range CHECK (attempts BETWEEN 0 AND 5)
);
CREATE INDEX IF NOT EXISTS otp_challenges_phone_time ON otp_challenges(phone,created_at DESC);
CREATE TABLE IF NOT EXISTS sms_gateway_devices (
 id text PRIMARY KEY, public_key_pem text NOT NULL, enabled boolean NOT NULL DEFAULT false,
 last_seen_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sms_gateway_jobs (
 id uuid PRIMARY KEY, challenge_id uuid NOT NULL UNIQUE REFERENCES otp_challenges(id),
 recipient text NOT NULL, encrypted_body text NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','leased','sent','failed','delivered')),
 device_id text REFERENCES sms_gateway_devices(id), sim_slot smallint,
 lease_until timestamptz, attempts integer NOT NULL DEFAULT 0,
 sent_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sms_gateway_jobs_poll ON sms_gateway_jobs(status,lease_until,created_at);
CREATE TABLE IF NOT EXISTS sms_gateway_nonces (
 device_id text NOT NULL REFERENCES sms_gateway_devices(id),
 nonce text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(device_id,nonce)
);
COMMIT;
