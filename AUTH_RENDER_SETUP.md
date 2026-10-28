# Login, registration, email verification, PostgreSQL

## Local update
From backend:
```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
```
New registration asks for username, email, password and confirmation. An email contains a single-use verification code, valid for 24 hours. Paste it in the app's verification screen, then log in. New accounts cannot log in until verified. Existing users and superusers are retained and remain usable. Login uses username. Tokens stay in app memory and last at most seven days; refresh requires login again.

For real email, create a Resend account, verify your sender/domain there, and put these values in the backend environment (do not commit keys):
```powershell
$env:RESEND_API_KEY = "YOUR_PRIVATE_KEY"
$env:DEFAULT_FROM_EMAIL = "Mandakhrank <noreply@YOUR_VERIFIED_DOMAIN>"
.\.venv\Scripts\python.exe manage.py runserver
```
Resend HTTPS API is used when that key exists. SMTP environment variables remain supported as an alternative. Actual inbox delivery has not been tested here; provider credentials are required.

For local-only testing without sending email:
```powershell
$env:EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
.\.venv\Scripts\python.exe manage.py runserver
```
Leave RESEND_API_KEY unset for console mode. The verification code appears in the Django terminal, not in an inbox. Restart after switching environment variables.

There is no resend or password-reset screen yet. For an expired/lost verification code during local testing, an admin can delete the inactive test account and register again. Do not delete an existing active account. Do not manually activate an unverified public account.

## Render deployment
No remote resource has been created yet. render.yaml is a prepared Blueprint, defining a Django web service and PostgreSQL database. Install/connect the Render integration to let the assistant continue provisioning, or use Render Dashboard → New → Blueprint after pushing this code to your repository. render.yaml belongs beside backend/ and frontend/ at the repository root.

Review Render's current plan availability and terms before applying the Blueprint. It requests free plans where available. It prompts for RESEND_API_KEY and DEFAULT_FROM_EMAIL; provide values privately in Render. Django gets DATABASE_URL and a generated secret key automatically.

The startup command runs migrations and creates Django's tables, including auth_user, catalog_emailverification, catalog_accesstoken and submission/problem/course tables. Passwords use Django's password hashing. Verification tokens are stored as SHA-256 hashes. The database is private to Render's network in the Blueprint.

This creates a NEW empty PostgreSQL database. It does not transfer local SQLite accounts, courses, completion history or submissions. Seed data and an admin account must be added to the remote database separately. Retain your SQLite file. Data migration needs a separate export/import step if you want existing local data preserved remotely.

Set CORS_ALLOWED_ORIGINS to your actual Flutter web origin when you host the frontend. Local Chrome http://localhost:5173 and http://127.0.0.1:5173 are allowed by default. Run local Flutter against the deployed API:
```powershell
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com/api
```
Flutter itself is not deployed by this Blueprint. Neither the Judge0 service nor the judge worker is provisioned here. Retain your prior judge setup, and configure its database to the same PostgreSQL database if moving judging to Render.

## Verification and limits
16 Django tests pass on SQLite, including inactive login rejection, verification token consumption, successful verified login and email failure rollback. Dart syntax checked. Flutter SDK, live PostgreSQL and email provider unavailable here, so those live integrations have not been tested. Add authentication/email request rate limits before opening registration to the public. No real users were emailed during development.
