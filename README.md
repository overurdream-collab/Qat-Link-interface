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

## Phase 2 application state

- Central in-memory `AppState` exposes customer and movement collections through `ValueNotifier`.
- Customer registration requests are always created as pending.
- Debt/payment requests are accepted only for customers approved by both parties.
- A financial movement is always created as pending, regardless of approval values supplied by a caller.
- Approval and rejection are recorded independently for the merchant and customer.
- A participant can submit only one decision per request; rejection is terminal.
- Immutable model copies are used when state changes.
- Workflow tests cover creation, approval, rejection, duplicate IDs, and invalid customer references.

### Security boundary for this phase

`ApprovalParty` is a domain-level workflow input, not proof of identity. The future authenticated application/backend layer MUST derive the approving party from the verified signed-in account and must not accept a party identity selected by the client UI. This phase remains in-memory and is not production multi-user security or persistent audit logging.
