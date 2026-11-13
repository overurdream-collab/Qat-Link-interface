# Qat-Link — مقتني لينك

A Flutter application for merchant customer accounts, debts, and collections.

## Phase 1 foundation

- Flutter / Dart project structure
- Material 3 light and dark themes
- Central domain models and accounting enums
- Pure movement calculation service
- Unit tests for dual-approval and per-currency accounting

## Mandatory two-party approval policy

**No record, customer registration, or financial movement is accepted or activated until both the merchant and the customer have approved it.**

- Every new customer starts pending approval from both parties.
- Every debt, payment, or other financial movement starts pending approval from both parties.
- One party's approval alone is never sufficient.
- Approval by both parties is required before a record is treated as approved.
- Rejection by either party rejects the request.
- Pending requests do not affect approved customer balances.
- Rejected movements are excluded from accounting totals.
- In later workflow/state-management phases, creation and update actions must enter an approval-request flow rather than directly changing approved records.

## Accounting invariants

- Approved debts increase customer debt.
- Approved payments reduce customer debt.
- Balances are calculated independently per currency; currencies are never combined.
- No opening balance is assumed.

## Run checks

```bash
flutter pub get
flutter test
flutter analyze
```

The UI and business logic are intentionally separated. Phase 1 does not implement persistence, authentication, or screens.
