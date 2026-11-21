# مقوتي — Premium Soft UI · 2026-11-21

## Scope and baseline
- Isolated from `feat/maqwati-green-identity-isolated-20261121` (green campaign branch).
- User-approved visual direction: Ksenia-inspired elevated soft UI with pale blue/lavender canvas, cyan→blue→violet gradients, translucent white panels, delicate shadows, rounded circular controls, and native Arabic Cairo typography.
- Branding: display name **مقوتي**. Original approved mascot remains reference; do not claim it has been recolored in current Flutter assets. The newly approved purple/blue mascot artwork requires adding the exact approved image asset before shipping.
- Source mockups are visual targets, not exact exports or production UI files; no copying third-party design assets.

## Applied in this experiment
- `lib/theme/premium_tokens.dart`: independent premium tokens and reusable elevated surfaces/round icon control.
- `lib/theme/app_colors.dart`: experimental palette for the copied branch only; green branch untouched. Semantic success, danger and pending values preserved as distinct statuses.
- `lib/screens/login_screen.dart`: airy gradient background, translucent login panel, cyan/blue/violet action, phone and existing four-digit PIN entry, password reveal, recovery affordance, GiC footer, support entry.
- `lib/screens/home_screen.dart`: merchant currency carousel with adjacent cards showing, using existing approved-only financial models; pending stays separate, no currency total.
- Login safety behavior remains unchanged: field validation is NOT a session. Form submission does NOT open merchant account until verified server authentication is integrated.
- No Google/Apple sign-in added.
- Customer preview remains a preview, not a login/session.

## Quality gates BEFORE approval
1. Run `flutter pub get && flutter analyze && flutter test` and Android debug build on this branch. Record exact run URL and SHA. Untested here.
2. Test layout at 320, 360, 390, 430dp widths, keyboard open, text scaling 1.0/1.3/1.6, RTL, accessibility contrast, touch targets >=44dp.
3. Confirm authorized merchant/customer sessions, recovery route, and customer support contact are real before production launch; current UI-only placeholders must not be represented as working.
4. Verify `login_phone`, `login_pin`, `login_submit`, registration, and reveal accessibility in widget tests; prohibit PIN-only local authentication.
5. Verify YER/SAR/USD independent approved balances and separate pending; synthetic data only. Do not alter FIN-08..FIN-25 ledger/auth services.
6. The wallet carousel currently uses adjacent previews and scale; a literal 3-card depth stack needs a separate, tested interactive component. Avoid claiming pixel-perfect parity with the mockup.

## Next screens
- Replace original green hero/banner assets with approved lavender/cyan mascot artwork, subject to source upload and license.
- Finish login support/recovery/registration as functional integrations instead of placeholders.
- Finalize merchant home and true 3-layer wallet carousel; design mobile navigation and studio button.
- Merchant clients, client details, movements, approvals, reports, analytics, store, settings.
- Customer home, linked merchants, approvals and statements.
- Widget/golden tests, keyboard and screen-reader audits, Android APK and sign-off.

## Merge policy
Keep the PR as **draft**. Do not merge into `main` or the green branch until all build, security, financial integrity and design checks pass. The previously approved UX/business rules remain binding; a visual prototype cannot change role permissions, double approvals, immutable approved movements or decimal accounting.

## Verified implementation ledger — 2026-11-21
- Code pushed on isolated branch; merchant and customer main screens share premium blue/lavender visual surfaces and centered 3-currency carousel.
- Login and merchant/customer navigation are restyled; UI test files added under `test/premium/`.
- Main app display title is `مقوتي`. The green branch is unchanged (comparison showed 0 commits behind green; only this feature branch is ahead).
- New GitHub Actions workflow `premium-soft-ui-ci.yml` includes flutter pub get, analyze, widget/domain tests, Android debug build, and log/APK artifact steps.
- **CI is not green**: workflow run [#44889254734](https://github.com/overurdream-collab/Qat-Link-interface/actions/runs/44889254734) was reported as failure. The connector exposed no job steps and the redirected log API returned BlobNotFound, so the failure cause has **not** been established; do not state that Flutter analysis, tests or APK passed.
- Approved blue/purple recolored mascot is not present as a separate verified repository asset; the existing owner mascot image remains an interim placeholder. No unauthorized source images or rendered screenshots were committed.
- This branch is a visual implementation pass; full screen-by-screen pixel approval and production auth/server wiring remain open gates.
