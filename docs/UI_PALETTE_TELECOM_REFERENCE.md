# لوحة ألوان مقوتي لنك — Telecom Dashboard reference

Source: HTML/CSS supplied by the product owner on 2026-11-15. This
document records an approved *visual palette change only*. It does not
modify the approved financial domain or its approval rules.

## Exact CSS → Flutter colors

| CSS variable | Hex | Flutter token |
|---|---|---|
| blue | #3A70D2 | AppColors.blue |
| blue-light | #497CD7 | AppColors.blueLight |
| blue-mid | #5A94DD | AppColors.blueMid |
| sky | #7FBDEC | AppColors.sky |
| cyan | #A4E6F2 | AppColors.cyan |
| mint | #B0E9DA | AppColors.mint |
| green | #CDEABE | AppColors.green |
| lime | #D5ECA6 | AppColors.lime |
| icon-green | #A5E8A1 | AppColors.iconGreen |
| button | #3868C8 | AppColors.button |
| navy | #0A0D3B | AppColors.navy |
| surface | #FFFFFF | AppColors.surface |
| section | #F6F6F6 | AppColors.section |
| background | #E5E8ED | AppColors.background |
| muted | #9DA5B8 | AppColors.muted |
| red-bg | #F8D9DD | AppColors.redBackground |

Two gradients are matched to the exact hex stops and proportions in the
reference CSS:

- **header (132°)**: #497CD7 at 3%, #76B7E7 at 45%, #A4DCCE at
  80%, #CDEABE at 100%. Flutter uses topLeft → bottomRight as an
  approximate geometric equivalent; CSS angle and Flutter alignment
  aren't strictly identical.
- **balance (180°)**: #3A70D2 at 0%, #5189DD at 52%, #89D0EC at 100%.

Additional CSS ring-color stops are stored in `AppColors`.

## Product-specific application

- The customer-facing finance UI uses the source's blue/sky/mint accents,
  white elevated sections, navy text, and rounded corner system.
- RTL, independent YER/SAR/USD currency selection, two-party approvals,
  financial net calculation and separation of pending transactions remain
  unchanged.
- Income/debt/payment numerical figures must always originate from
  verified financial read models. No sample money is hard-coded.
- Status colors (success, pending, rejected) are semantic rather than
  decorative and require accompanying text/icons.
- `lib/main.dart` and `lib/screens/home_screen.dart` are an early
  **read-only UI shell**: they use an empty local `AppState` and have
  not been wired to authenticated backend data. Buttons show this
  limitation rather than pretending to create financial records.
- The Cairo typeface is mandated by the project specification but not yet
  bundled in this repository; a font asset and pubspec registration are
  required before guaranteeing Cairo rendering across platforms.

## Validation

Run on a configured Flutter machine:

```bash
flutter pub get
dart format lib/main.dart lib/screens/home_screen.dart lib/theme test/theme
flutter analyze
flutter test
flutter run
```

No runtime compile/test result should be claimed from this documentation.
