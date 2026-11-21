# Security policy — Maqwati Link

This repository includes financial records, identity flows and a separate offline UI preview. **The app is not authorized for production launch until P0 gates in docs/RELEASE_SECURITY_FINANCE_AUDIT_2026-11-21_AR.md are signed off.**

## Reporting vulnerabilities
Please submit vulnerabilities privately through the repository's **Security → Advisories → Report a vulnerability** feature if enabled, or contact repository administrators through an approved secure internal channel.

Do not publish exploitation steps, access tokens, OTPs, customer phone numbers, ledgers, names, images or production logs in ordinary GitHub Issues, comments, pull requests or screenshots. All tests must use a staging environment and synthetic records unless a separate authorization exists.

For ordinary bugs use the GitHub issue template and provide only:
- exact build/commit and affected feature;
- reproducible steps using synthetic account records;
- severity and expected/actual behavior;
- safe diagnostics event name and UTC time;
- a redacted CI run URL if available.

## Response and release controls
1. Triage P0 ledger integrity, authorization bypass, exposed secrets, OTP compromise or cross-account data exposure as a launch blocker.
2. Reproduce only on isolated staging with synthetic data and redacted evidence.
3. Fix in a dedicated branch with a regression test and peer review. Require FIN08 PostgreSQL migration tests, Flutter tests, dependency scan and security gate evidence.
4. Confirm least-privilege DB roles, verified identity, TLS, backups and two-party approvals.
5. Follow up with privacy-preserving incident monitoring. Do not embed GitHub or observability admin tokens in APK.

**Privacy:** In-app incident exports contain only enumerated incident class and UTC time. Automatic forwarding is disabled until an authenticated telemetry endpoint with documented consent, rate limits, access policy and retention is approved.
