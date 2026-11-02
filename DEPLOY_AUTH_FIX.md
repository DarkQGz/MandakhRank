# MandakhRank: repair email verification + sign-in on Render

This update fixes application-side login and signup recovery while retaining the existing Django database, users, problems, and migration history. **You must still deploy and authorize a Gmail sender yourself.** Do not send anyone your Google password, App Password, script secret, Render login, or access token.

## What changed

- Sign in with **username or registered email**, matching usernames without case sensitivity.
- An account that registered but has **not yet verified** is guided to the verification screen instead of receiving an unexplained login failure. A wrong password still returns a generic error.
- Repeating registration with the **same username, email and correct password** resumes an unverified registration: returns the old code if it is still within the 60-second resend cooldown, otherwise sends a fresh code.
- Browser sign-in persists across page reloads using Flutter `shared_preferences` (7-day backend token lifetime). Sign-out clears local storage. As with most browser bearer-token storage, avoid signing in on untrusted/shared devices.
- New `python manage.py check_mailer` validates backend configuration without sending. `--to address@example.com` sends a real test message from your computer/server environment.
- Mailer exceptions are sanitized in user responses and logs (type only); logs do not contain email addresses, verification codes, or secrets.

## 1. Keep your existing Render database and service

On Render, open your **existing** `mandakhrank-api` service. Do **not** create a new service, reset the DB, remove the `DATABASE_URL`, or delete any previous migrations. `render.yaml` refers to `mandakhrank-db` in Oregon, but check your actual deployed service's database name. Keep the existing `DJANGO_SECRET_KEY` unchanged.

Go to Render > **Environment**. Set these exactly:

| Variable | Value |
|---|---|
| `EMAIL_BACKEND` | `catalog.email_backend.GmailScriptBackend` |
| `GMAIL_SCRIPT_URL` | Your web app URL, exactly `https://script.google.com/macros/s/DEPLOYMENT_ID/exec` |
| `GMAIL_SCRIPT_SECRET` | The same **64 lowercase hexadecimal characters** as `MAILER_SECRET` in Script Properties |
| `DATABASE_URL` | **Leave your existing connection string unchanged** |
| `DJANGO_SECRET_KEY` | **Leave your existing secret unchanged** |
| `DJANGO_DEBUG` | `0` |

**Do not set** `EMAIL_BACKEND` to SMTP or console for production. `DEFAULT_FROM_EMAIL` is set internally. Do not use `smtp.gmail.com`: Render Free blocks SMTP ports 25/465/587, so the sender uses HTTPS instead.

## 2. Gmail account setup (one-time, done by the account owner)

1. Use a dedicated Gmail address you control (any valid Gmail account). Sign in yourself at https://script.google.com/ and create a **New project**.
2. Paste the whole contents of `google-mailer/Code.gs` into the project's `Code.gs`, then Save.
3. Generate a secret locally in PowerShell (Windows):

   ```powershell
   $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
   $bytes = New-Object byte[] 32
   $rng.GetBytes($bytes)
   $rng.Dispose()
   ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
   ```

   This outputs 64 lowercase hex characters. **Never commit or share the value.**
4. In Google Apps Script: Project Settings > **Script Properties** > add `MAILER_SECRET` with that exact secret.
5. Choose Deploy > **New deployment** > **Web app**; choose **Execute as: Me** and **Who has access: Anyone** (public/anonymous; not "any Google account" only). Authorize the requested mail-sending permission yourself. If your Google account blocks this access setting, use an account whose policies allow it.
6. Copy the deployment URL ending in `/exec`. Add that URL and the same secret in Render Environment (step 1). Never paste the secret into Flutter/Dart or a GitHub repository.
7. When you edit the Google script later: Deploy > **Manage deployments** > Edit > New version > Deploy. Saving the code without deploying a new version does **not** update the web app.

Opening your `/exec` URL in the browser should show `{"ok":false,"message":"POST only"}`. That confirms only that the script endpoint is reachable, not that Gmail delivery works.

## 3. Build Flutter web, push code, and redeploy existing Render service

Merge the extracted `mandakhrank` project files into your **existing Git repo**. Keep any private `.env`, local DB, custom environment config and git history. In Windows PowerShell from your repo root:

```powershell
flutter doctor
.\scripts\build-web.ps1 -ApiBaseUrl "https://mandakhrank-api.onrender.com/api"
git add backend frontend google-mailer render.yaml scripts DEPLOY_AUTH_FIX.md
# build-web.ps1 copies compiled Flutter files into backend/webapp; stage those too:
git add -f backend/webapp
git commit -m "Fix Gmail verification and login recovery"
git push
```

> If the Render service is at a **different** URL, replace `https://mandakhrank-api.onrender.com/api` in the build command with `https://YOUR-SERVICE.onrender.com/api`. If Flutter is not on PATH, use the Flutter SDK location on your machine. Make sure `backend/webapp/index.html` exists after the build. The archive does not include a compiled frontend.

Then Render > your existing service > **Manual Deploy** > **Deploy latest commit** (or wait for auto-deploy). Watch deploy logs for `migrate`, successful Gunicorn startup and the correct latest commit. Do not migrate a different database.

## 4. Verify it works

1. Go to the deployed site, use a **new email**, and register. You should see the four-digit verification screen. After Gmail receives the code, enter it and the app should sign in.
2. Log out, log in using either email or username, reload the page, and confirm you are still signed in. Sessions are server-authorized for 7 days.
3. If an email never arrives, check Spam. In your Google Apps Script editor, open **Executions**. If no execution is listed, check the Render `GMAIL_SCRIPT_URL`, web app access, and deployment. If an execution fails, check Google permissions, quota, and Script Properties (with no secrets posted publicly).
4. If Render replies with HTTP **503** during registration, mail delivery failed or environment variables are invalid. Its logs should show a safe failure type. If login returns **403**, the password is correct but the account is awaiting email verification. If login returns **401**, the username/email or password is wrong.

### Optional local configuration and mail delivery test

In a trusted local PowerShell session **without committing credentials**, set the three values from the table and run:

```powershell
cd backend
$env:EMAIL_BACKEND = "catalog.email_backend.GmailScriptBackend"
$env:GMAIL_SCRIPT_URL = "https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec"
$env:GMAIL_SCRIPT_SECRET = "YOUR_SECRET_FROM_SCRIPT_PROPERTIES"
python manage.py check_mailer
python manage.py check_mailer --to "your-own-inbox@gmail.com"
```

The command does not need a production DB to test mail delivery. The first command only validates settings; the second makes a real Gmail call. Remove your secret from shell history if entered directly. Do not run this in untrusted terminal sessions.

## Troubleshooting existing accounts

- An account from the old password login implementation can sign in with its **old password**. There is no automatic change to existing passwords.
- An account that was created but never verified can go to **Code / get a new code**, enter the same registration email and original password, and request a code (after the 60-second cooldown). Or repeat registration with the same username/email/password.
- If an account was created in an older Firebase-only release with no Django password, its old Firebase password cannot be recovered or copied automatically. Such accounts require a separately authorized password reset by the site administrator. Do not set `is_active=True` for unverified accounts as a workaround.
- If your prior account disappeared, check that the Render service is pointing to the **original DATABASE_URL**. Accounts are held in PostgreSQL, not Flutter.

## What has / has not been validated

Static Python source compilation and the offline Google Apps Script tests were run successfully. Django tests and Flutter tests could not be executed in this packaging environment because Django/Flutter are not installed, and this environment cannot download packages. Run the project's tests on your own machine before redeploying:

```powershell
cd backend
pip install -r requirements.txt
python manage.py test catalog
cd ..\frontend
flutter pub get
flutter test
```

Gmail/Apps Script authorization and real email delivery, Render environment values, and a production deployment cannot be verified from a source ZIP alone.

Official guidance: https://developers.google.com/apps-script/guides/web and https://render.com/docs/free
