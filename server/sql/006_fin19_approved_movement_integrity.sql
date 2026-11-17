-- P0: validate every approved movement against its authoritative source.
-- Apply after 001_fin08.sql and 002_fin13_unified_ledger.sql.
-- Deployment role must own DDL; application role must not own tables or triggers.
BEGIN;
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
DROP TRIGGER IF EXISTS fin19_approved_movement_source_guard ON financial_movements;
CREATE TRIGGER fin19_approved_movement_source_guard
BEFORE INSERT ON financial_movements
FOR EACH ROW EXECUTE FUNCTION fin19_validate_approved_movement();
COMMIT;
