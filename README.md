# MandakhRank — Gmail verification

Start with **[GMAIL_SETUP.md](GMAIL_SETUP.md)**.

This release uses dedicated Gmail through Google Apps Script, four-digit verification and automatic login. No Firebase, Resend, custom domain, Gmail password in Flutter, or OAuth client setup required.

Django handles accounts, verified codes, CMS, submissions, solved status and the real leaderboard. Judge0 still executes code externally. A small HTTPS Google sender must be deployed and authorized once by the Gmail account owner.

Run `scripts/build-web.ps1`, commit source and backend/webapp, and deploy your existing Render service. Keep existing migrations and database. See VALIDATION.md for test coverage and limitations.
