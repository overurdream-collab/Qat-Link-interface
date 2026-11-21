-- FIN-18 / P0: verify provenance and exact approved accounting facts at the DB boundary.
-- PostgreSQL 16+; additive, after 001..005. Runtime DB role must NOT own
-- financial_movements, run DDL, disable triggers or have superuser privileges.
-- This guards direct INSERT as well as the API, but DOES NOT replace RLS,
-- least privilege, verified identity or complete authorization checks.
BEGIN;

CREATE OR REPLACE FUNCTION fin18_approved_movement_source_integrity()
RETURNS trigger LANGUAGE plpgsql AS $fin18$
DECLARE
  valid_source boolean := false;
BEGIN
  IF NEW.status <> 'approved' THEN
    RAISE EXCEPTION 'Only approved financial movements may be posted';
  END IF;

  IF (NEW.source_claim_id IS NULL) = (NEW.source_operation_id IS NULL) THEN
    RAISE EXCEPTION 'Exactly one approved source must be specified';
  END IF;

  IF NEW.source_claim_id IS NOT NULL THEN
    -- Prior registration claim: independent customer acceptance, approved
    -- relationship, merchant contact, active sole verified phone owner and
    -- immutable claim amount/currency/type must ALL agree.
    SELECT EXISTS(
      SELECT 1
      FROM merchant_claims cl
      JOIN customer_claim_decisions d
        ON d.claim_id = cl.id AND d.decision = 'accept'
        AND d.merchant_id = cl.merchant_id
      JOIN merchant_relationships r
        ON r.id = NEW.relationship_id AND r.status = 'approved'
        AND r.merchant_id = cl.merchant_id
        AND r.customer_id = d.customer_id
        AND r.contact_id = cl.contact_id
      JOIN merchant_contacts mc
        ON mc.id = cl.contact_id AND mc.merchant_id = cl.merchant_id
      JOIN verified_contact_links vl
        ON vl.merchant_id = cl.merchant_id AND vl.contact_id = cl.contact_id
        AND vl.customer_id = d.customer_id
      JOIN customer_phone_evidence ev
        ON ev.proof_reference = vl.proof_reference
        AND ev.customer_id = vl.customer_id
        AND ev.normalized_phone = mc.normalized_phone
        AND ev.revoked_at IS NULL
      WHERE cl.id = NEW.source_claim_id
        AND NEW.merchant_id = cl.merchant_id
        AND NEW.customer_id = d.customer_id
        AND NEW.amount = cl.amount
        AND NEW.currency = cl.currency
        AND NEW.type = cl.operation_type
        AND NEW.reversal_of_movement_id IS NULL
        AND cl.superseded_by_claim_id IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM financial_amendment_requests am
          WHERE am.original_claim_id = cl.id AND am.status = 'pending'
        )
        AND (
          SELECT COUNT(DISTINCT ev2.customer_id)
          FROM customer_phone_evidence ev2
          WHERE ev2.normalized_phone = mc.normalized_phone
            AND ev2.revoked_at IS NULL
        ) = 1
    ) INTO valid_source;
  ELSE
    -- Ordinary relationship operation: exact, approved, same-party and
    -- same-currency source, including reversal reference.
    SELECT EXISTS(
      SELECT 1
      FROM relationship_operations op
      JOIN merchant_relationships r ON r.id = op.relationship_id
      WHERE op.id = NEW.source_operation_id
        AND op.status = 'approved'
        AND r.status = 'approved'
        AND op.decided_by IS NOT NULL
        AND op.decided_at IS NOT NULL
        -- The creator must be the represented party, and the decision must
        -- come from its actual counterparty, not a fabricated ID.
        AND (
          (op.created_by_role = 'merchant'
           AND op.created_by = r.merchant_id
           AND op.decided_by = r.customer_id)
          OR
          (op.created_by_role = 'customer'
           AND op.created_by = r.customer_id
           AND op.decided_by = r.merchant_id)
        )
        AND (
          (op.approval_method = 'manual'
           AND op.auto_policy_version IS NULL)
          OR
          (op.approval_method = 'delegated_policy'
           AND op.created_by_role = 'merchant'
           AND op.operation_type = 'debt'
           AND op.auto_policy_version IS NOT NULL
           AND EXISTS (
             SELECT 1 FROM relationship_policy_events pe
             WHERE pe.relationship_id = op.relationship_id
               AND pe.version = op.auto_policy_version
               AND pe.enabled = true
               AND pe.actor_id = r.customer_id
               AND pe.happened_at <= op.created_at
           ))
        )
        AND NEW.relationship_id = op.relationship_id
        AND NEW.merchant_id = op.merchant_id
        AND NEW.customer_id = op.customer_id
        AND r.merchant_id = op.merchant_id
        AND r.customer_id = op.customer_id
        AND NEW.amount = op.amount
        AND NEW.currency = op.currency
        AND NEW.type = op.operation_type
        AND NEW.reversal_of_movement_id IS NOT DISTINCT FROM op.reversal_of_movement_id
    ) INTO valid_source;
  END IF;

  IF NOT COALESCE(valid_source, false) THEN
    RAISE EXCEPTION 'Approved movement differs from authorized source'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$fin18$;

DROP TRIGGER IF EXISTS fin18_movement_source_guard ON financial_movements;
CREATE TRIGGER fin18_movement_source_guard
  BEFORE INSERT ON financial_movements
  FOR EACH ROW EXECUTE FUNCTION fin18_approved_movement_source_integrity();

COMMIT;
