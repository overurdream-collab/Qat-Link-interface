# Samsung Note 10 enrollment — local laptop pilot

Status: manual enrollment only; no automatic SMS sending enabled.

1. On the Windows laptop, run the Maqwati OTP transport and PostgreSQL in a private Docker network. Apply `server/sql/007_otp_android_gateway.sql` using a migration role. Keep `OTP_ENABLED=false` and do not expose PostgreSQL or the OTP transport directly to the Internet.
2. Publish only the HTTPS gateway API through an authenticated, trusted TLS endpoint (for example a properly configured tunnel or reverse proxy). A private LAN IP over HTTP is deliberately rejected by the Android client.
3. Install the debug APK on Samsung Note 10. Tap **إنشاء مفتاح الجهاز الآمن**, then **نسخ المفتاح العام ومعرّف الجهاز للمسؤول**. The 3072-bit private RSA key remains inside Android Keystore.
4. Transfer the public key and device ID to the laptop using an authenticated private channel. Verify the SHA-256 fingerprint shown on the phone matches the fingerprint of the received public key.
5. As database administrator, insert the device record **disabled**, using parameterized SQL or a trusted database client:

```sql
INSERT INTO sms_gateway_devices(id, public_key_pem, enabled)
VALUES (:device_id, :public_key_pem, false)
ON CONFLICT (id) DO NOTHING;
```

6. After confirming the physical phone and fingerprint, approve explicitly:

```sql
UPDATE sms_gateway_devices SET enabled = true
WHERE id = :device_id AND public_key_pem = :public_key_pem AND enabled = false;
```

7. Enter the trusted HTTPS base URL in the Android app and tap **حفظ العنوان وفحص اعتماد الجهاز**. A successful signed heartbeat proves the server recognizes the approved public key. Do not use the test endpoint to send SMS.
8. To revoke the device: `UPDATE sms_gateway_devices SET enabled=false WHERE id=:device_id;`. Revocation is enforced by signature verification on subsequent requests.

Important:
- The `:device_id` and `:public_key_pem` placeholders are database-client parameters, not literal psql variables. Do not paste untrusted PEM into shell commands.
- Registration approval currently requires a database administrator; no enrollment API or admin dashboard has been implemented.
- If the application is reinstalled and the Keystore key disappears, revoke the old device and enroll a new public key.
- Keep private keys, HMAC secrets, encryption keys, and OTP messages out of GitHub and logs.
- The Android UI only checks signed heartbeat. Foreground polling, OTP delivery, and end-to-end phone testing remain pending.
