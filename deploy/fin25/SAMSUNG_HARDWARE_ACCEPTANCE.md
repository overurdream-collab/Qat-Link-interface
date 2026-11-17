# FIN25 Samsung hardware acceptance gate (not yet passed)

## Verified in GitHub CI
- FIN25 JWT, gateway RSA security and isolated PostgreSQL integration tests.
- Synthetic HTTP OTP request -> simulated SMS sent -> verification -> single-use proof.
- No real carrier SMS or physical device operation is implied by these tests.

## Hard blockers for a real Samsung test
1. Install the APK from `overurdream-collab/smsgateway` PR #2 on the intended Samsung handset; verify its exact commit and package signature.
2. Provide a reachable HTTPS hostname with a trusted certificate and working DNS (the current 127.0.0.1:8443 self-signed localhost certificate is not sufficient for a separate phone).
3. Establish Android-to-backend FIN25 request canonicalization interoperability (raw JSON body, method, path, millisecond timestamp, nonce and RSA-SHA256 Base64 signature).
4. Enroll the Android device, verify private-key possession and approve it administratively only after independent operator review.
5. Confirm SIM subscription ID/slot mapping and runtime SEND_SMS permission, background service operation, reconnection, and explicit destination consent.
6. Use a test-only recipient and controlled carrier plan. Keep FIN25_SMS_DISPATCH_ENABLED=false until operator authorizes a bounded live trial.
7. Run one OTP: request, poll, send, result, verify, proof redeem; verify one-time semantics and no OTP retention in logs.
8. Test offline recovery, duplicate ACK, replayed nonce, wrong device key, wrong SIM, expired lease, and process restart without duplicate SMS.
9. Record masked recipient, device identifier, test run ID, timestamp, status and evidence without recording the OTP itself.
10. Re-disable dispatch after the trial and review audit logs before any release decision.

## Safety / acceptance
- No production financial DB migration or merge to main is authorized by this document.
- Identity JWT issuance remains external to FIN25 transport; proof redemption alone is not login.
- Real SMS delivery, Android service reliability and identity-provider integration remain unverified until hardware evidence is attached.
