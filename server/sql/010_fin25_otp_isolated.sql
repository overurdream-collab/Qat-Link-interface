-- FIN25 OTP queue isolated from legacy sms_gateway_* and financial tables.
BEGIN;
CREATE TABLE IF NOT EXISTS fin25_otp_challenges (
 id uuid PRIMARY KEY, phone text NOT NULL, code_digest char(64) NOT NULL,
 expires_at timestamptz NOT NULL, resend_after timestamptz NOT NULL,
 attempts integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
 consumed_at timestamptz, proof_digest char(64) UNIQUE,
 proof_expires_at timestamptz, proof_redeemed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fin25_otp_challenges_phone_time ON fin25_otp_challenges(phone,created_at DESC);
CREATE TABLE IF NOT EXISTS fin25_sms_jobs (
 id uuid PRIMARY KEY,
 challenge_id uuid NOT NULL UNIQUE REFERENCES fin25_otp_challenges(id),
 recipient text NOT NULL, encrypted_body text NOT NULL,
 status text NOT NULL DEFAULT 'pending'
 CHECK(status IN ('pending','leased','sent','failed','delivered')),
 device_id uuid REFERENCES fin25_gateway_devices(device_id),
 sim_slot smallint, lease_until timestamptz, attempts integer NOT NULL DEFAULT 0,
 sent_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fin25_sms_jobs_poll ON fin25_sms_jobs(status,created_at);
COMMIT;
