# FIN25 — Docker LAN + Samsung test handoff (not production)
The two services run behind one TLS endpoint. SMS dispatch is **OFF** by default on both the server and the Android app. Do not enable until security and concurrency tests pass and the device is administratively approved.

## Requirements
Docker Compose, PostgreSQL 16 test database (NOT the financial production database), trusted TLS certificate whose SAN includes the host LAN IP or DNS, Android phone on the same network. Never use cleartext HTTP or disable Android TLS validation.

## Isolated database
Apply `server/sql/fin25/009_fin25_gateway_isolated.sql` then `server/sql/fin25/010_fin25_otp_isolated.sql` to a **separate** test database, with a migration role. Both services use the same DATABASE_URL; existing financial migrations 001–008 remain unchanged.

## Configure
In `deploy/fin25` create a private `.env` (never commit it) with:
```dotenv
DATABASE_URL=postgresql://fin25_app:REPLACE@host.docker.internal:5432/fin25_test
FIN25_ADMIN_KEY=REPLACE_WITH_32_PLUS_RANDOM_CHARACTERS
OTP_HMAC_SECRET=REPLACE_WITH_RANDOM_SECRET
OTP_ENCRYPTION_KEY_HEX=REPLACE_WITH_64_HEX_CHARACTERS
OTP_INTERNAL_API_KEY=REPLACE_WITH_RANDOM_SECRET
JWT_PUBLIC_KEY_PEM=-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----
JWT_ISSUER=REPLACE_WITH_REAL_IDENTITY_ISSUER
JWT_AUDIENCE=REPLACE_WITH_REAL_IDENTITY_AUDIENCE
OTP_ENABLED=false
FIN25_SMS_DISPATCH_ENABLED=false
```
Use your real issuer's **public** key only, never its signing private key. Place trusted `certs/server.crt` and `certs/server.key` (do not commit) in this directory. On Windows Docker Desktop, host.docker.internal resolves to the host; ensure PostgreSQL permits the Docker network and only test DB credentials.

Run from `deploy/fin25`:
```sh
docker compose config
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 enrollment otp https
```
The backend processes bind to 0.0.0.0 **inside their private Docker network only** so Caddy can reach them; neither service publishes its port to the host. Only Caddy publishes 8443.\n\nThe HTTPS URL entered on Samsung is `https://YOUR_CERTIFICATE_HOSTNAME_OR_LAN_IP:8443`. Trust the issuing CA on the phone if using a private CA. A self-signed untrusted server certificate will be rejected.

## Enroll and prove
1. On Samsung create Android Keystore key and copy Device ID + public SPKI PEM + fingerprint.
2. On a trusted admin terminal POST `/v1/gateway/enroll` with JSON `{"deviceId":"UUID","publicKeyPem":"PEM"}` and header `X-FIN25-ADMIN-KEY`. **Never put this key in the Android app.**
3. Tap 'إثبات امتلاك مفتاح الجهاز' on Samsung. This requests a short-lived challenge, signs it locally, and proves possession.
4. Admin verifies fingerprint out-of-band and POSTs `/v1/gateway/approve` with `{"deviceId":"UUID"}` plus admin key.
5. Tap connection test; heartbeat must succeed. Revocation: POST `/v1/gateway/revoke` with deviceId and admin key.

## OTP + JWT
The OTP transport never mints JWT. `/v1/internal/otp/proof` requires **both** a valid RS256 Bearer token with role `identity_service` issued by the trusted JWT issuer **and** `X-Internal-API-Key`. It returns a phone number only once for an unexpired proof; the trusted identity service must then resolve the user, apply its own enrollment and role rules, and issue JWT. A verified phone alone must never grant merchant/customer privileges.

## SMS test activation (ONLY after gates pass)
After PostgreSQL integration, RSA replay tests, OTP lifecycle, Android Build and concurrency/disconnect tests are all green, a trusted operator can set `OTP_ENABLED=true` and `FIN25_SMS_DISPATCH_ENABLED=true` in the local test .env and restart OTP container. Then explicitly enable SMS test on the phone and start its foreground worker. The app resets local SMS opt-in to false on each restart. This is NOT automatic activation.

## Current limits
- No actual Samsung SMS transmission has been observed or verified here.
- Multipart SMS and robust lease recovery are not implemented; uncertain leased jobs must be manually reconciled, never auto-requeued.
- No identity-provider JWT issuance adapter is implemented: identity service must consume one-time proof using the contract above.
- Admin enrollment and approval are API operations, not an admin UI.
- Test against a dedicated database, never production.


Release integration note (2026-11-24): schema files are namespaced by service; apply only to their separate databases. Production Identity startup now requires `IDENTITY_PG_SSL=true` and a trusted PostgreSQL server certificate; production FIN25 requires `PG_SSL=true`. The historical Compose database has no TLS provisioning, so this is an explicit rollout blocker until the operator provisions verified TLS. These source files have not been deployed or used to restart existing services. Public OTP and SMS dispatch remain disabled by default. Local operator `/v1/auth/otp/request` requires the existing identity_service JWT and internal API key.
