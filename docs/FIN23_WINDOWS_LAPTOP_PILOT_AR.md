# FIN23 — Windows 11 laptop pilot: prerequisites and release gates

> Status: preparation only. **Do not** treat a successful debug APK build as a functioning login. The Flutter login remains deliberately locked until real OTP and session integration is tested.

## Prerequisites

- Windows 11, Node.js 22+, PostgreSQL 16, Flutter SDK, Android SDK and a real Android test phone.
- An Android SMS Gateway with registered device keys, active SIM, outbound HTTPS polling and working SMS delivery.
- A trusted identity component implementing real OTP issue/delivery/verify, RS256 JWT issuance, short-lived access tokens, refresh-token rotation, revocation and account/device binding. **This is not yet implemented in this repository.**
- A secure network path from the phone to the laptop (same trusted Wi-Fi for initial testing). Never expose PostgreSQL to the Internet. HTTPS must use a certificate trusted by the phone; do not disable certificate verification.
- Use only synthetic test accounts and balances until full end-to-end verification.

## Database setup (PowerShell)

Run in an isolated test database. Set `DATABASE_URL` securely in the current process; do not commit credentials. From the repository root:

```powershell
cd server
npm ci
npm run check
$env:FIN08_TEST_DATABASE_URL = $env:DATABASE_URL
npm test
```

**Before** the database integration tests, initialize the isolated database with migrations **001 through 007 in filename order**, using `psql -v ON_ERROR_STOP=1`. Verify each migration succeeds; do not skip a failed migration or run against a production database. For example, from `server`:

```powershell
Get-ChildItem .\sql\0*.sql | Sort-Object Name | ForEach-Object {
  psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f $_.FullName
  if ($LASTEXITCODE -ne 0) { throw "Migration failed: $($_.Name)" }
}
```

Do not re-run the migration sequence on an existing database without reviewing idempotence and taking a verified backup first.

## Start backend (after trusted identity is available)

Required environment variables: `DATABASE_URL`, `AUTH_PUBLIC_KEY_PEM`, `AUTH_ISSUER`, `AUTH_AUDIENCE`, `CURSOR_SECRET` (at least 32 random characters). Optional: `PORT` (default 8080), `PG_SSL` for remote database TLS. Never put secrets in Git or Flutter assets.

```powershell
npm start
Invoke-RestMethod http://127.0.0.1:8080/healthz
```

A successful `/healthz` is **not** proof of OTP delivery, token issuance, database correctness, or device connectivity.

## Android debug APK

Flutter CI builds an **unsigned-for-release debug APK** and publishes the artifact `qat-link-android-debug-apk`. Download it from the successful GitHub Actions run and extract the ZIP. This APK is **not production-signed** and the current login intentionally cannot authenticate. Do not claim end-to-end readiness based on installation alone.

## Mandatory end-to-end acceptance tests

1. Android Gateway is paired and authenticated using a per-device key; heartbeat and SIM status verified.
2. Request OTP for a synthetic account, observe SMS delivery to a real phone, reject expired/reused/wrong codes and rate-limit attempts. Never log or persist plaintext OTP.
3. Verify OTP and issue short-lived RS256 access token with server-derived role and subject, plus refresh token stored hashed server-side and protected on device.
4. Rotate refresh token; verify replay detection, logout/revocation, session expiry and device-change behavior.
5. Flutter uses the verified server session; cannot open financial screens from local PIN or client-provided roles. Financial relationship and movement approvals remain independent.
6. Run PostgreSQL financial integration tests after all seven migrations; verify cross-relationship isolation and no effect of pending/rejected movements.
7. Validate Android-to-laptop HTTPS access on the actual network, recovery after disconnection and restart, and backup/restore on a separate database.

**Release gate:** Not ready for real merchant/customer pilot until items 1–7 pass and evidence is recorded.
