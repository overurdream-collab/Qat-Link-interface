# Qat-Link — مقتني لينك

A Flutter application for merchant customer accounts, debts, and collections.

## Phase 1 foundation

- Flutter / Dart project structure
- Material 3 light and dark themes
- Central domain models and accounting enums
- Pure movement calculation service
- Unit tests for approval-aware, per-currency accounting

## Accounting invariants

- Pending movements never affect approved balances.
- Rejected movements are excluded from all totals.
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
