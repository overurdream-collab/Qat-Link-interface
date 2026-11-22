# Premium Soft UI source-branch extraction and safe port — 2026-11-22

**Source:** `feat/maqwati-premium-soft-ui-20261121`
**Destination:** `feat/maqwati-green-identity-isolated-20261121`
**No main merge. No server, authentication, ledger, approval or data-model changes.**

## Source inspection
Compared both branches. They have diverged: the source has substantial premium-UI files, while the destination has independent login/theme changes. A full merge or wholesale overwrite risks losing newer work and altering unrelated features.

The source’s own docs disclose that Android CI has failed without usable runner logs (Issue #69) and the recolored violet mascot image is not present as a standalone approved asset. These remain unverified.

## Imported implementation
- `lib/theme/premium_tokens.dart`: the original reusable PremiumVisualPalette (blue/pink and light/dark) with PremiumSurface and PremiumRoundButton; registered as ThemeExtension in app_theme.dart.
- `lib/widgets/auth/auth_brand_hero.dart`: the original layered dimensional wordmark and responsive Yemeni mascot composition, corrected **from مقوتي to مقوتي لينك**; tagline remains **كل يوم حكاية**. Existing local mascot image is retained.
- `lib/screens/login_screen.dart`: complete original glass login card, gradients, language presentation, customer service placeholder, GiC footer, phone and four-digit code, signup and recovery controls, and clearly marked preview section. No Google/Apple login.
- `lib/widgets/home/premium_home_hero.dart`: original reusable responsive promotional card; corrected brand name to **مقوتي لينك**.
- `lib/screens/home_screen.dart` and `lib/widgets/home/new_currency_card.dart`: original currency carousel and approved net-balance display. Both approved debt and payment values use Decimal accounting, pending remains separate, and negative net is customer credit. Preserved the destination's existing seven-banner HeroCarousel instead of deleting it.
- Six premium tests copied from source (approved login, credit balance, feminine palette, hero responsiveness, login safety and wallets), plus destination test updates and Windows verification script adapted to its actual branch name.

## Important exclusions
- The exact approved violet costume art is **not available in the source branch** as a separately verified image asset. Do not invent, claim recoloring, or substitute an unapproved image.
- Source documentation explicitly called the product merely «مقوتي», but the owner's later direction explicitly makes the official name **«مقوتي لينك»**. The later decision is applied to imported runtime components.
- Do not reuse source README or script instructions that silently point to the source branch or promise successful builds.
- No changes were made under `lib/models/`, `lib/services/`, or `server/`.
- The login remains demonstrational with real Flutter inputs but does not authenticate against the server. 'تذكرني', recovery, customer support and previews are not live integrations.

## Verification pending
1. `flutter pub get`
2. `flutter analyze --no-fatal-infos`
3. `flutter test`
4. `flutter build apk --debug`, phone review in 320/360/390/430dp, all four themes and keyboard open.
5. Confirm GitHub Actions runner works, otherwise use `scripts/premium-ui-verify.ps1` on a trusted Windows Flutter installation and examine logs.
6. Preview build is not a production financial app; no merge into main or release claim without these gates.
