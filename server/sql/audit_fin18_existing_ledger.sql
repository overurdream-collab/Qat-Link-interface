-- Read-only, privacy-preserving accounting consistency gate.
-- Run on staging or a restored DB. Emits aggregate counts only, no names,
-- phone numbers, ledger IDs or amounts.
DO $audit$
DECLARE
  invalid_count bigint;
BEGIN
  SELECT COUNT(*) INTO invalid_count
  FROM financial_movements fm
  JOIN merchant_relationships r ON r.id=fm.relationship_id
  WHERE NOT (
    fm.status='approved'
    AND fm.merchant_id=r.merchant_id
    AND fm.customer_id=r.customer_id
    AND (
      (
        fm.source_claim_id IS NOT NULL
        AND fm.source_operation_id IS NULL
        AND fm.reversal_of_movement_id IS NULL
        AND EXISTS (
          SELECT 1 FROM merchant_claims cl
          JOIN customer_claim_decisions d ON d.claim_id=cl.id
          WHERE cl.id=fm.source_claim_id
            AND d.decision='accept'
            AND d.merchant_id=cl.merchant_id
            AND d.customer_id=fm.customer_id
            AND d.merchant_id=fm.merchant_id
            AND cl.contact_id=r.contact_id
            AND cl.merchant_id=fm.merchant_id
            AND cl.amount=fm.amount
            AND cl.currency=fm.currency
            AND cl.operation_type=fm.type
        )
      ) OR (
        fm.source_operation_id IS NOT NULL
        AND fm.source_claim_id IS NULL
        AND EXISTS (
          SELECT 1 FROM relationship_operations op
          WHERE op.id=fm.source_operation_id
            AND op.status='approved'
            AND op.decided_at IS NOT NULL
            AND op.decided_by IS NOT NULL
            AND (
              (op.created_by_role='merchant'
               AND op.created_by=r.merchant_id
               AND op.decided_by=r.customer_id)
              OR
              (op.created_by_role='customer'
               AND op.created_by=r.customer_id
               AND op.decided_by=r.merchant_id)
            )
            AND (
              (op.approval_method='manual'
               AND op.auto_policy_version IS NULL)
              OR
              (op.approval_method='delegated_policy'
               AND op.created_by_role='merchant'
               AND op.operation_type='debt'
               AND EXISTS (
                 SELECT 1 FROM relationship_policy_events pe
                 WHERE pe.relationship_id=op.relationship_id
                   AND pe.version=op.auto_policy_version
                   AND pe.enabled=true
                   AND pe.actor_id=r.customer_id
                   AND pe.happened_at<=op.created_at
               ))
            )
            AND op.relationship_id=fm.relationship_id
            AND op.merchant_id=fm.merchant_id
            AND op.customer_id=fm.customer_id
            AND op.amount=fm.amount
            AND op.currency=fm.currency
            AND op.operation_type=fm.type
            AND op.reversal_of_movement_id IS NOT DISTINCT
              FROM fm.reversal_of_movement_id
        )
      )
    )
  );

  -- Existing orphan relationships must also fail the release gate.
  invalid_count := invalid_count + (
    SELECT COUNT(*) FROM financial_movements fm
    WHERE NOT EXISTS (
      SELECT 1 FROM merchant_relationships r WHERE r.id=fm.relationship_id
    )
  );
  IF invalid_count > 0 THEN
    RAISE EXCEPTION 'FIN18 provenance mismatches: % (ledger remains unchanged)', invalid_count;
  END IF;
  RAISE NOTICE 'FIN18 existing ledger provenance: PASS (aggregate mismatch count 0)';
END;
$audit$;
