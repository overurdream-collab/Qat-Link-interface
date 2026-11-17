-- FIN19 direct-SQL regression. Run after 001..006 on an isolated PostgreSQL 16 DB.
-- All fixtures and successful writes are rolled back.
BEGIN;
INSERT INTO merchant_profiles(merchant_id,verified_display_name)
VALUES('fin19-test-merchant','FIN19 Merchant');
INSERT INTO merchant_contacts(id,merchant_id,display_name,normalized_phone)
VALUES('11111111-1111-4111-8111-111111111111','fin19-test-merchant','FIN19 Customer','+967777000001'),
      ('11111111-1111-4111-8111-111111111112','fin19-test-merchant','FIN19 Other','+967777000002');
INSERT INTO merchant_claims(id,merchant_id,contact_id,amount,currency,idempotency_key,request_digest)
VALUES('22222222-2222-4222-8222-222222222221','fin19-test-merchant',
'11111111-1111-4111-8111-111111111111',1,'USD','fin19-test-1',repeat('a',64)),
('22222222-2222-4222-8222-222222222222','fin19-test-merchant',
'11111111-1111-4111-8111-111111111111',1,'USD','fin19-test-2',repeat('b',64));
INSERT INTO merchant_relationships(id,merchant_id,customer_id,contact_id,status)
VALUES('33333333-3333-4333-8333-333333333331','fin19-test-merchant','fin19-test-customer',
'11111111-1111-4111-8111-111111111111','approved'),
('33333333-3333-4333-8333-333333333332','fin19-test-merchant','fin19-test-other',
'11111111-1111-4111-8111-111111111112','approved');
INSERT INTO customer_claim_decisions(claim_id,merchant_id,customer_id,decision)
VALUES('22222222-2222-4222-8222-222222222221','fin19-test-merchant','fin19-test-customer','accept'),
('22222222-2222-4222-8222-222222222222','fin19-test-merchant','fin19-test-customer','accept');
-- Correct approved entry must post.
INSERT INTO financial_movements(id,source_claim_id,relationship_id,merchant_id,customer_id,amount,currency,type)
VALUES('44444444-4444-4444-8444-444444444441','22222222-2222-4222-8222-222222222221',
'33333333-3333-4333-8333-333333333331','fin19-test-merchant','fin19-test-customer',1,'USD','debt');
-- Direct SQL attack: 999 SAR and a different relationship must fail.
DO $$
BEGIN
  BEGIN
    INSERT INTO financial_movements(id,source_claim_id,relationship_id,merchant_id,customer_id,amount,currency,type)
    VALUES('44444444-4444-4444-8444-444444444442','22222222-2222-4222-8222-222222222222',
    '33333333-3333-4333-8333-333333333332','fin19-test-merchant','fin19-test-other',999,'SAR','debt');
    RAISE EXCEPTION 'FAIL: forged ledger entry was accepted';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: forged ledger entry rejected (23514)';
  END;
  BEGIN
    INSERT INTO financial_movements(id,source_claim_id,relationship_id,merchant_id,customer_id,amount,currency,type)
    VALUES('44444444-4444-4444-8444-444444444443','22222222-2222-4222-8222-222222222222',
    '33333333-3333-4333-8333-333333333331','fin19-test-merchant','fin19-test-customer',999,'SAR','debt');
    RAISE EXCEPTION 'FAIL: forged amount/currency accepted';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: forged amount/currency rejected';
  END;
  BEGIN
    DELETE FROM merchant_claims WHERE id='22222222-2222-4222-8222-222222222221';
    RAISE EXCEPTION 'FAIL: posted claim deleted';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: posted claim deletion rejected';
  END;
  BEGIN
    UPDATE financial_movements SET amount=999 WHERE id='44444444-4444-4444-8444-444444444441';
    RAISE EXCEPTION 'FAIL: approved ledger mutated';
  EXCEPTION WHEN raise_exception THEN
    RAISE NOTICE 'PASS: approved ledger immutable';
  END;
  BEGIN
    UPDATE merchant_claims SET amount=999 WHERE id='22222222-2222-4222-8222-222222222221';
    RAISE EXCEPTION 'FAIL: posted claim was mutated';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: posted claim is immutable';
  END;
  BEGIN
    UPDATE customer_claim_decisions SET decision='reject'
    WHERE claim_id='22222222-2222-4222-8222-222222222221';
    RAISE EXCEPTION 'FAIL: posted decision was mutated';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: posted decision is immutable';
  END;
  BEGIN
    UPDATE customer_claim_decisions SET merchant_id='fin19-test-other'
    WHERE claim_id='22222222-2222-4222-8222-222222222221';
    RAISE EXCEPTION 'FAIL: posted decision merchant identity mutated';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: posted decision merchant identity immutable';
  END;
  BEGIN
    UPDATE merchant_relationships SET contact_id='11111111-1111-4111-8111-111111111112'
    WHERE id='33333333-3333-4333-8333-333333333331';
    RAISE EXCEPTION 'FAIL: posted relationship identity was mutated';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: posted relationship identity is immutable';
  END;
END $$;
ROLLBACK;
