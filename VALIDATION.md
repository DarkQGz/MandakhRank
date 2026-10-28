# Gmail release validation

- 38 Django tests passed on SQLite, including verification expiry/replay/guess limits/resend, auto-login, submission privacy, judging, real rankings, and Gmail sender success/failure handling.
- Gmail backend tests verify leading-zero preservation, single-recipient payload, HTTPS URL restrictions, missing-secret rejection, sanitized errors and network failures. HTTP provider calls are mocked.
- Offline JavaScript tests passed for the Google script: wrong-secret rejection, malformed code/multiple-recipient rejection, quota exhaustion, 10/minute throughput limit and POST-only handling. MailApp is mocked; no emails sent.
- `makemigrations --check --dry-run`: no missing migrations. FirebaseIdentity and migration 0005 are retained for upgrade compatibility; Firebase authentication is not used.
- Flutter restores the earlier four-digit UI. Flutter build/widget tests were not executed in this environment; run scripts/build-web.ps1 locally. No compiled web build included.
- Gmail account, Apps Script deployment/authorization, Google execution behavior, real delivery, live Render deployment and browser/device end-to-end flow have not been tested or configured. These require account-owner setup described in GMAIL_SETUP.md.
- Uses Google Apps Script HTTPS because Render Free blocks common SMTP ports. Personal Google account email quota currently 100 recipients/day, subject to Google's changes. This is a small-project sender, not a high-volume production mail service.
