# MandakhRank — registration, Gmail verification & login repair

Start with **[DEPLOY_AUTH_FIX.md](DEPLOY_AUTH_FIX.md)** for the setup and deployment steps.

This package contains updated Django + Flutter source. It supports registration with a four-digit Gmail verification code (Google Apps Script over HTTPS), verification recovery, login with username or email, and persistent browser sessions. Google account authorization and Render environment configuration are still required; no Gmail password is placed in source or the app.

To deploy: configure Apps Script, set the Render environment variables, run `scripts/build-web.ps1`, commit the generated `backend/webapp`, and redeploy your *existing* Render service. Preserve your current database and `DJANGO_SECRET_KEY`. `GMAIL_SETUP.md` contains additional Mongolian setup instructions.

**Not a prebuilt app:** no Flutter compiled web assets or live Gmail credentials are contained in this archive.
