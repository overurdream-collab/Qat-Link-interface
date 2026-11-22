# Maqwati Link — four-theme screen coverage audit
Date: 2026-11-22
Target branch: `feat/maqwati-green-identity-isolated-20261121`

## Scope
Owner-approved blue/purple day and night, plus female rose/orchid day and night. Cairo, RTL and Premium Soft UI remain common. Historical branch name "green" must not be interpreted as active visual identity.

## Inspected Flutter screen groups
- App shell, global top and bottom navigation, login and registration.
- Merchant: home, clients, client details, movement, assistant, space/studio, bookings, approvals, pending contacts.
- Customer: shell, wallet view, store/discovery, customer relationship, claim approvals.
- FIN-08, FIN-13, FIN-15 and FIN-16 presentation screens.
- Shared quick actions, invitations/QR and home campaign carousel.

## Current audit corrections uploaded
1. Removed hardcoded blue-brand accents from merchant clients button, movement shadow, assistant banner shadow, navigation divider shadow and quick-action icons. These now follow the selected theme.
2. Replaced generic blue-only assistant/summary gradients with `context.premium.action` in movement, client details and financial assistant.
3. Customer wallet currency gradients now use the selected `PremiumVisualPalette` YER/SAR/USD palette in both day and night, including female pink.
4. Customer shared hero/banner now follows `context.premium.hero`.
5. Female banner order now also detects pink night theme, not just the daytime pink primary swatch. Added matching widget regression.
6. Login bottom waves detect pink night; title, tagline and decorative halo follow feminine palette while male blue-gradient branding remains intact. Female logo uses the exact owner-provided pink values.
7. Currency-card circular progress accent uses a neutral light foreground for contrast.
8. Added `test/theme/visual_theme_coverage_test.dart` to assert header and all 12 (4 themes × 3 currencies) widget combinations; included in isolated CI workflow.
9. The six imported premium tests and existing theme/widget tests remain in repository. Financial state colors retain separate semantic roles and no financial model or server files were modified.

## Intentional exceptions to brand-color substitution
- Success, rejected, pending, delinquency and warning status colors are semantic, not brand colors; they should **not** be turned pink or purple.
- QR modules remain near-black on white for reliable scanning.
- The seven existing image assets are campaigns; their fixed interior colors are not dynamically recolored.
- Approved male character image remains in the project. The exact approved isolated female/rose mascot image is not present as a verified asset; a screen mockup is not an appropriate runtime substitute.

## Release verification required
Code review and GitHub writes are verified. **Flutter execution is not verified in this environment.**
- Run `flutter pub get` and `flutter analyze --no-fatal-infos`.
- Run `flutter test`, including `test/theme/visual_theme_coverage_test.dart` and `test/widgets/home_banner_carousel_test.dart`.
- Build a debug Android APK and inspect screenshots at 320, 360, 390 and 430dp, with Arabic text scaling, software keyboard open, blue/pink and day/night combinations.
- Validate pink female artwork after the approved image is supplied as its own asset.
- Authenticate real sessions only after server-backed OTP/login integration; the current UI preview intentionally cannot grant a session.
- Do not merge to `main` or announce production readiness before passing these gates.
