-- Run against a fresh, disposable PostgreSQL database ONLY, never FIN25.
-- This should abort if the identity phone constraint accepts invalid numbers.
BEGIN;
INSERT INTO identity_accounts(subject,phone,role,finance_proof_reference,display_name)
VALUES ('11111111-1111-4111-8111-111111111111','+967771234567','merchant',
        '22222222-2222-4222-8222-222222222222','تاجر اختبار');
DO $$
DECLARE invalid_number TEXT;
BEGIN
  FOREACH invalid_number IN ARRAY ARRAY[
    '967771234567','+966771234567','+96777123456',
    '+9677712345678','+967abc456789','++967771234567'
  ] LOOP
    BEGIN
      INSERT INTO identity_accounts(subject,phone,role,finance_proof_reference)
      VALUES (gen_random_uuid(), invalid_number,'customer',gen_random_uuid());
      RAISE EXCEPTION 'Invalid phone was accepted: %', invalid_number USING ERRCODE='P0002';
    EXCEPTION
      WHEN check_violation THEN NULL;
    END;
  END LOOP;
END $$;
DO $$
DECLARE found_role TEXT;
BEGIN
  SELECT role INTO found_role FROM identity_accounts WHERE phone='+967771234567';
  IF found_role IS DISTINCT FROM 'merchant' THEN RAISE EXCEPTION 'Valid phone was rejected'; END IF;
  BEGIN
    INSERT INTO identity_accounts(subject,phone,role,finance_proof_reference)
    VALUES (gen_random_uuid(), '+967771234567','customer',gen_random_uuid());
    RAISE EXCEPTION 'Duplicate phone accepted' USING ERRCODE='P0002';
  EXCEPTION
    WHEN unique_violation THEN NULL;
  END;
END $$;
DO $$
DECLARE session_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO identity_sessions(id,subject,role,refresh_hash,device_id,expires_at)
  VALUES (session_id,'11111111-1111-4111-8111-111111111111','merchant',
          repeat('a',64),'33333333-3333-4333-8333-333333333333',now()+interval '30 days');
  BEGIN
    INSERT INTO identity_sessions(id,subject,role,refresh_hash,device_id,expires_at)
    VALUES (gen_random_uuid(),'11111111-1111-4111-8111-111111111111','merchant',
            repeat('a',64),'33333333-3333-4333-8333-333333333333',now()+interval '30 days');
    RAISE EXCEPTION 'Duplicate refresh hash accepted' USING ERRCODE='P0002';
  EXCEPTION
    WHEN unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity_sessions(id,subject,role,refresh_hash,device_id,expires_at)
    VALUES (gen_random_uuid(),'11111111-1111-4111-8111-111111111111','merchant',
            'not-a-hash','33333333-3333-4333-8333-333333333333',now()+interval '30 days');
    RAISE EXCEPTION 'Invalid refresh hash accepted' USING ERRCODE='P0002';
  EXCEPTION
    WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity_sessions(id,subject,role,refresh_hash,device_id,expires_at)
    VALUES (gen_random_uuid(),'11111111-1111-4111-8111-111111111111','merchant',
            repeat('b',64),'not-a-device',now()+interval '30 days');
    RAISE EXCEPTION 'Invalid device id accepted' USING ERRCODE='P0002';
  EXCEPTION
    WHEN check_violation THEN NULL;
  END;
END $$;
ROLLBACK;
