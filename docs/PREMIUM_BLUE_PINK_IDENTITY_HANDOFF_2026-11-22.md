# Maqwati Link — approved Premium identity implementation
Date: 2026-11-22
Target branch: `feat/maqwati-green-identity-isolated-20261121`

## Scope and isolation
This change intentionally modifies the **existing isolated green branch**, as instructed by the owner. The branch name is historical: the app preview within it now uses the newer blue/violet identity. No merge to `main`, payment-ledger logic changes, or backend authorization changes are included.

## Design specification implemented
- Full product name: **مقوتي لينك**, not merely مقوتي.
- Tagline: **كل يوم حكاية**.
- Arabic font family: Cairo, from the existing licensed repository asset.
- Blue daylight: #328BF5, #7939EA, #C2A4FF, #73DCF6, #4358F5; background #F2F3FF; text #111A4B; muted #767FAE.
- Pink daylight: #AD3379, #AD4389, #8551B2; background #FFEFF6; primary text #45233D; muted #866A82.
- Blue night: background #171A3C; text #F3F3FF.
- Pink night: background #251B30; text #FFEFF7.
- 3D brand-name gradient: #8CF6FF → #0FA7F9 → #0752E6 → #2533AE. Tagline #5730C4.
- Premium Soft UI: rounded translucent floating login panel, soft shadows, pill-form fields, circular feature icons.
- Unified role-neutral sign-in: phone and existing **four-digit login code**. The UI includes remember-me presentation and recovery action but does not claim working auth.
- Card gradients independent for each currency, with distinct blue and pink variants:
  - Blue YER: #6F6CE8 / #4B88F4 / #83D5F8
  - Blue SAR: #45A3D9 / #76D8F1 / #A8E4EF
  - Blue USD: #7458D1 / #997DF6 / #B9A9F7
  - Pink YER: #A23478 / #AC3E81 / #B7468A
  - Pink SAR: #963E77 / #A74A82 / #AD5388
  - Pink USD: #69429D / #7D4BA8 / #8B56B6

## Files
- `lib/screens/login_screen.dart`: floating premium form, phone and login code, visual remember-me control, signup and recovery UI.
- `lib/widgets/auth/auth_brand_hero.dart`: 3D full brand name, tagline, locally referenced mascot, ambient gradient.
- `lib/theme/app_colors.dart`: global theme tokens and currency-specific gradients.
- `lib/theme/app_theme.dart`: Cairo, shared Soft UI shapes.
- `lib/widgets/app_chrome.dart`, `lib/screens/customer_app_shell.dart`: consistent elevated navigation and currency presentation.
- `lib/widgets/home/new_currency_card.dart`: per-currency gradients for both themes.
- Existing palette tests updated; `test/theme/premium_identity_tokens_test.dart` added.

## Known limitations and release gates
1. **Do not label this a production release.** The existing login screen deliberately blocks session creation until verified backend authentication is connected. Valid local input only yields a notice.
2. The existing form authenticates no one. The visual 'تذكرني' control currently changes in-memory checkbox state only; no device token is stored.
3. The photo at `assets/images/maqwati_approved_mascot.jpeg` remains the pre-existing locally committed mascot. A pixel-identical blue/purple recolored mascot asset has **not** been uploaded by this change; the artwork must be separately reviewed before claiming the reference mockup is replicated exactly.
4. Real Flutter analyze, Flutter widget tests, Android APK build and on-device screenshot review require a successful GitHub Actions run or local Flutter environment. Code uploads alone do not establish PASS.
5. This branch still uses a historical green preview workflow/package name. Renaming its branch, its APK package, or merging it into `main` is deliberately outside this isolated UI task.
6. Theme changes must never alter financial statuses, approvals, currencies or any approved-only balance calculation.

## Acceptance checklist
- [ ] CI: `flutter analyze --no-fatal-infos` passes.
- [ ] CI: `flutter test` passes including `premium_identity_tokens_test.dart`.
- [ ] Android APK builds, and no login without server authentication.
- [ ] Visual review at 320px, 360px, 390px, and tablet widths; daylight/night, blue/pink.
- [ ] Mascot art reviewed for fidelity to approved image.
- [ ] Financial cards for YER/SAR/USD verified in both blue and pink themes.
