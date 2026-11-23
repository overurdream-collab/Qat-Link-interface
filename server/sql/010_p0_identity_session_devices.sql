-- Bind every refreshable identity session to a stable install/device id.
-- Existing pre-device sessions are forced to re-authenticate by the service.
ALTER TABLE identity_sessions ADD COLUMN IF NOT EXISTS device_id text;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='identity_sessions_device_id_format'
  ) THEN
    ALTER TABLE identity_sessions ADD CONSTRAINT identity_sessions_device_id_format
      CHECK (device_id IS NULL OR device_id ~ '^[a-fA-F0-9-]{36}$');
  END IF;
END $$;
