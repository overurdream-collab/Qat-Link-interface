-- PostgreSQL NUMERIC NaN compares greater than zero and equals itself.
-- Existing CHECK(amount>0) and source-equality checks alone accept NaN.
-- Additive after001..008; fail and roll back on historic non-finite values.
-- Never silently rewrite financial data; reconcile anomalies before retrying.
BEGIN;
ALTER TABLE merchant_claims ADD CONSTRAINT fin_finite_claim_amount
  CHECK (amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
ALTER TABLE financial_movements ADD CONSTRAINT fin_finite_movement_amount
  CHECK (amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
ALTER TABLE relationship_operations ADD CONSTRAINT fin_finite_operation_amount
  CHECK (amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
ALTER TABLE financial_amendment_requests
  ADD CONSTRAINT fin_finite_amendment_original CHECK (original_amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)),
  ADD CONSTRAINT fin_finite_amendment_proposed CHECK (proposed_amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
ALTER TABLE relationship_credit_limits ADD CONSTRAINT fin_finite_credit_limit
  CHECK (limit_amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
ALTER TABLE relationship_credit_limit_events
  ADD CONSTRAINT fin_finite_limit_previous CHECK (previous_amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)),
  ADD CONSTRAINT fin_finite_limit_event CHECK (limit_amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
ALTER TABLE financial_payment_allocation_requests ADD CONSTRAINT fin_finite_allocation_request
  CHECK (amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
ALTER TABLE financial_payment_allocation_entries ADD CONSTRAINT fin_finite_allocation_entry
  CHECK (amount NOT IN ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric));
COMMIT;
