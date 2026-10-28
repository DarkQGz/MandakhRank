# Validation — 2026-10-28

- `python manage.py test catalog`: **32 tests passed** (SQLite).
- Coverage: four-digit leading zeros, auto-login, expired/replayed/wrong codes, five-guess limit, resend cooldown/password, email failure rollback, case-insensitive duplicate email, login throttling, hidden-test privacy, per-user submission privacy, Judge0 verdicts, queued worker execution, stalled-work recovery, unique accepted-problem scoring, equal-point distinct problems, inactive/staff exclusions, web index serving, and startup seed preservation.
- `python manage.py makemigrations --check --dry-run`: no missing migrations.
- Python compile check passed.
- `render.yaml` validated against Render JSON Schema. This does not apply or deploy infrastructure.
- Dart formatter parsed all six Dart source/test files successfully; final format check passed.
- Flutter widget tests were added for automatic fourth-digit verification and invalid-code handling, plus updated navigation tests. **Not executed here.**
- Flutter SDK bootstrap/build verification was blocked by automatic approval review because setup attempted to access the cloud instance metadata endpoint. No retry of that route was made. A release web build is **not included**; run `scripts/build-web.ps1` with your own Flutter installation before deploying.
- Live email delivery, live Judge0 execution, PostgreSQL concurrency, mobile packaging, and browser visual rendering have not been tested. Email/Judge0 tests use mocks, not provider credentials.
- This ZIP does not change the live Render service or GitHub repository. Follow UPGRADE.md using the existing service/database.
