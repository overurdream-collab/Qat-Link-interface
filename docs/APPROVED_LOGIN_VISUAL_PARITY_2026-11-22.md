# Visual parity follow-up — 2026-11-22

Target: `feat/maqwati-green-identity-isolated-20261121`

## Strict owner reference
The user-uploaded original blue male login screenshot (not the later generated variations) is the design baseline. Do not replace its smiling blue-and-white Yemeni character, turban, embroidered vest, or jambiya; no check mark or blue roundel above the name. Login headline must read **مقوتي لينك**, tagline **كل يوم حكاية**. The pink female identity has the same glass layout and rounded spacing but a feminine pink/orchid palette. No jambiya on the woman. Do not add a row of four decorative service icons; it was introduced in a later generated mockup and is not in the owner screenshot.

## Actual code changes in this pass
- `lib/screens/login_screen.dart`: outer glass-like rounded perimeter using the existing theme gradient, 43px radius, translucent border, soft shadow and clipping, without changing auth submission semantics.
- `test/screens/approved_login_glass_frame_test.dart`: regression checks at 320dp and 390dp across blue/pink × day/night for frame geometry, hero, tagline, phone/PIN and layout overflow.
- `.github/workflows/maqwati-green-isolated.yml`: dedicated step requires these regression tests to pass before financial regression or preview APK packaging.

## Asset verification and current blocker
The repository currently contains `assets/images/maqwati_approved_mascot.jpeg` but no independently uploaded female 3D character asset. An approved visually matched, dagger-free pink woman cutout has been prepared in the conversation working environment, but it is **not** yet committed to the branch. Do not claim completed visual parity for the pink theme until its PNG/WebP source is actually stored in GitHub and wired into `AuthBrandHero`. A full-page picture is not an acceptable replacement for interactive login controls.

## Verification standard
1. CI Flutter analyze + all relevant widget tests pass.
2. Full Flutter regression passes.
3. Android offline preview builds and passes the existing package/permission gates.
4. Side-by-side screenshot comparisons on 320/360/390/430dp Android screens for male/female, day/night, open keyboard and large Arabic text.
5. Visual sign-off for both independent character assets.
6. This is an **offline design preview**, not production login; do not infer an authenticated session or mark the full financial app production-ready.

CI success alone verifies programmatic correctness, not pixel-perfect identity. No main-branch merge authorized.
