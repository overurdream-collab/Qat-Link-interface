-- P0: validate every approved movement against its authoritative source.
-- Apply after migrations 001 through 005, including FIN-15 amendment tables.
-- Deployment role must own DDL; application role must not own tables or triggers.
BEGIN;
LOCK TABLE financial_movements IN SHARE ROW EXCLUSIVE MODE;
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

-- Existing posted rows must be valid BEFORE the trigger is installed.
DO $
DECLARE invalid_count bigint;
BEGIN
  SELECT count(*) INTO invalid_count FROM financial_movements fm
  LEFT JOIN merchant_claims cl ON cl.id=fm.source_claim_id
  LEFT JOIN customer_claim_decisions d ON d.claim_id=cl.id AND d.customer_id=fm.customer_id
  LEFT JOIN merchant_relationships r ON r.id=fm.relationship_id
  LEFT JOIN relationship_operations o ON o.id=fm.source_operation_id
  WHERE fm.status <> 'approved'
     OR (fm.source_claim_id IS NOT NULL AND (
         cl.id IS NULL OR d.decision IS DISTINCT FROM 'accept'
         OR d.merchant_id IS DISTINCT FROM cl.merchant_id
         OR r.id IS NULL OR r.merchant_id IS DISTINCT FROM cl.merchant_id
         OR r.customer_id IS DISTINCT FROM d.customer_id
         OR r.contact_id IS DISTINCT FROM cl.contact_id
         OR r.status IS DISTINCT FROM 'approved'
         OR ROW(fm.merchant_id,fm.amount,fm.currency,fm.type)
            IS DISTINCT FROM ROW(cl.merchant_id,cl.amount,cl.currency,cl.operation_type)))
     OR (fm.source_operation_id IS NOT NULL AND (
         o.id IS NULL OR o.status IS DISTINCT FROM 'approved'
         OR r.status IS DISTINCT FROM 'approved'
         OR ROW(fm.merchant_id,fm.customer_id,fm.relationship_id,fm.amount,fm.currency,fm.type,fm.reversal_of_movement_id)
            IS DISTINCT FROM ROW(o.merchant_id,o.customer_id,o.relationship_id,o.amount,o.currency,o.operation_type,o.reversal_of_movement_id)));
  IF invalid_count > 0 THEN
    RAISE EXCEPTION 'FIN19 preflight: % invalid approved ledger rows; investigate before migration', invalid_count
      USING ERRCODE='23514';
  END IF;
END $;

-- Authoritative source facts must not be rewritten after an approved posting.
CREATE OR REPLACE FUNCTION fin19_protect_posted_source()
RETURNS trigger LANGUAGE plpgsql AS $
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
    IF posted AND (TG_OP='DELETE' OR ROW(NEW.claim_id,NEW.customer_id,NEW.decision)
      IS DISTINCT FROM ROW(OLD.claim_id,OLD.customer_id,OLD.decision))
    THEN RAISE EXCEPTION 'Posted customer decision is immutable' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='merchant_relationships' THEN
    SELECT EXISTS(SELECT 1 FROM financial_movements WHERE relationship_id=OLD.id) INTO posted;
    IF posted AND (TG_OP='DELETE' OR ROW(NEW.merchant_id,NEW.customer_id,NEW.contact_id)
      IS DISTINCT FROM ROW(OLD.merchant_id,OLD.customer_id,OLD.contact_id))
    THEN RAISE EXCEPTION 'Posted relationship identity is immutable' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $;
DROP TRIGGER IF EXISTS fin19_claim_source_immutable ON merchant_claims;
CREATE TRIGGER fin19_claim_source_immutable BEFORE UPDATE OR DELETE ON merchant_claims
FOR EACH ROW EXECUTE FUNCTION fin19_protect_posted_source();
DROP TRIGGER IF EXISTS fin19_operation_source_immutable ON relationship_operations;
CREATE TRIGGER fin19_operation_source_immutable BEFORE UPDATE OR DELETE ON relationship_operations
FOR EACH ROW EXECUTE FUNCTION fin19_protect_posted_source();
DROP TRIGGER IF EXISTS fin19_decision_source_immutable ON customer_claim_decisions;
CREATE TRIGGER fin19_decision_source_immutable BEFORE UPDATE OR DELETE ON customer_claim_decisions
FOR EACH ROW EXECUTE FUNCTION fin19_protect_posted_source();
DROP TRIGGER IF EXISTS fin19_relationship_source_immutable ON merchant_relationships;
CREATE TRIGGER fin19_relationship_source_immutable BEFORE UPDATE OR DELETE ON merchant_relationships
FOR EACH ROW EXECUTE FUNCTION fin19_protect_posted_source();

DROP TRIGGER IF EXISTS fin19_approved_movement_source_guard ON financial_movements;
CREATE TRIGGER fin19_approved_movement_source_guard
BEFORE INSERT ON financial_movements
FOR EACH ROW EXECUTE FUNCTION fin19_validate_approved_movement();
COMMIT;
