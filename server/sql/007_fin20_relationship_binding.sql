-- FIN20: close cross-relationship operation forgery and posted decision merchant identity mutation.
-- Run after FIN19/006. Existing rows are checked before replacement; failure rolls back all changes.
BEGIN;
LOCK TABLE financial_movements IN SHARE ROW EXCLUSIVE MODE;
DO $$
DECLARE invalid_count bigint;
BEGIN
 SELECT count(*) INTO invalid_count
 FROM financial_movements fm
 JOIN relationship_operations o ON o.id=fm.source_operation_id
 LEFT JOIN merchant_relationships r ON r.id=o.relationship_id
 WHERE r.id IS NULL OR r.merchant_id IS DISTINCT FROM o.merchant_id
    OR r.customer_id IS DISTINCT FROM o.customer_id;
 IF invalid_count > 0 THEN
   RAISE EXCEPTION 'FIN20 preflight: % posted operations disagree with relationship identity', invalid_count USING ERRCODE='23514';
 END IF;
END $$;
CREATE OR REPLACE FUNCTION fin19_validate_approved_movement()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  expected record;
BEGIN
  IF NEW.source_claim_id IS NOT NULL THEN
    SELECT cl.merchant_id, d.customer_id, cl.amount, cl.currency,
           cl.operation_type AS type, r.id AS relationship_id,
           r.status AS relationship_status, d.decision,
           cl.superseded_by_claim_id
      INTO expected
      FROM merchant_claims cl
      JOIN customer_claim_decisions d ON d.claim_id=cl.id
      JOIN merchant_relationships r
        ON r.merchant_id=cl.merchant_id AND r.customer_id=d.customer_id
       AND r.contact_id=cl.contact_id
       AND d.merchant_id=cl.merchant_id
      WHERE cl.id=NEW.source_claim_id
      FOR SHARE OF cl,d,r;
    IF NOT FOUND OR expected.relationship_status IS DISTINCT FROM 'approved'
       OR expected.decision IS DISTINCT FROM 'accept'
       OR expected.superseded_by_claim_id IS NOT NULL
       OR EXISTS (SELECT 1 FROM financial_amendment_requests a
                  WHERE a.original_claim_id=NEW.source_claim_id AND a.status='pending')
    THEN
      RAISE EXCEPTION 'Approved movement requires an accepted, eligible claim and approved relationship'
        USING ERRCODE='23514';
    END IF;
  ELSIF NEW.source_operation_id IS NOT NULL THEN
    SELECT o.merchant_id,o.customer_id,o.amount,o.currency,
           o.operation_type AS type,o.relationship_id,
           o.status AS operation_status,r.status AS relationship_status,
           o.reversal_of_movement_id
      INTO expected
      FROM relationship_operations o
      JOIN merchant_relationships r ON r.id=o.relationship_id
        AND r.merchant_id=o.merchant_id AND r.customer_id=o.customer_id
      WHERE o.id=NEW.source_operation_id
      FOR SHARE OF o,r;
    IF NOT FOUND OR expected.operation_status IS DISTINCT FROM 'approved'
       OR expected.relationship_status IS DISTINCT FROM 'approved'
       OR expected.reversal_of_movement_id IS DISTINCT FROM NEW.reversal_of_movement_id
    THEN
      RAISE EXCEPTION 'Approved movement requires an approved operation and relationship'
        USING ERRCODE='23514';
    END IF;
  ELSE
    RAISE EXCEPTION 'Exactly one authoritative source is required' USING ERRCODE='23514';
  END IF;
  -- Reject malformed historic rows rather than silently accepting an unsafe ledger.
  IF ROW(NEW.merchant_id,NEW.customer_id,NEW.amount,NEW.currency,NEW.type,NEW.relationship_id)
     IS DISTINCT FROM
     ROW(expected.merchant_id,expected.customer_id,expected.amount,expected.currency,
         expected.type,expected.relationship_id)
     OR NEW.status IS DISTINCT FROM 'approved'
  THEN
    RAISE EXCEPTION 'Approved movement differs from authoritative source'
      USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION fin19_protect_posted_source()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE posted boolean;
BEGIN
  IF TG_TABLE_NAME='merchant_claims' THEN
    SELECT EXISTS(SELECT 1 FROM financial_movements WHERE source_claim_id=OLD.id) INTO posted;
    IF posted AND (TG_OP='DELETE' OR
      ROW(NEW.merchant_id,NEW.contact_id,NEW.amount,NEW.currency,NEW.operation_type,NEW.superseded_by_claim_id)
      IS DISTINCT FROM ROW(OLD.merchant_id,OLD.contact_id,OLD.amount,OLD.currency,OLD.operation_type,OLD.superseded_by_claim_id))
    THEN RAISE EXCEPTION 'Posted claim source is immutable' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='relationship_operations' THEN
    SELECT EXISTS(SELECT 1 FROM financial_movements WHERE source_operation_id=OLD.id) INTO posted;
    IF posted AND (TG_OP='DELETE' OR
      ROW(NEW.relationship_id,NEW.merchant_id,NEW.customer_id,NEW.amount,NEW.currency,NEW.operation_type,NEW.reversal_of_movement_id,NEW.status)
      IS DISTINCT FROM ROW(OLD.relationship_id,OLD.merchant_id,OLD.customer_id,OLD.amount,OLD.currency,OLD.operation_type,OLD.reversal_of_movement_id,OLD.status))
    THEN RAISE EXCEPTION 'Posted operation source is immutable' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='customer_claim_decisions' THEN
    SELECT EXISTS(SELECT 1 FROM financial_movements WHERE source_claim_id=OLD.claim_id) INTO posted;
    IF posted AND (TG_OP='DELETE' OR ROW(NEW.claim_id,NEW.customer_id,NEW.merchant_id,NEW.decision)
      IS DISTINCT FROM ROW(OLD.claim_id,OLD.customer_id,OLD.merchant_id,OLD.decision))
    THEN RAISE EXCEPTION 'Posted customer decision is immutable' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='merchant_relationships' THEN
    SELECT EXISTS(SELECT 1 FROM financial_movements WHERE relationship_id=OLD.id) INTO posted;
    IF posted AND (TG_OP='DELETE' OR ROW(NEW.merchant_id,NEW.customer_id,NEW.contact_id)
      IS DISTINCT FROM ROW(OLD.merchant_id,OLD.customer_id,OLD.contact_id))
    THEN RAISE EXCEPTION 'Posted relationship identity is immutable' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;

COMMIT;
