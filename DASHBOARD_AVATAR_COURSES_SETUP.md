# MandakhRank — Student dashboard, registered users and course management

This is an **incremental patch** for the existing MandakhRank repository. It does not replace the functioning `docker_pull` judge or Gmail authentication. Make a Git commit or copy of your current repository before overwriting modified files.

## What's added

- `/admin/overview/`: superuser-only management dashboard showing registered students, email-verification counts, submissions and courses.
- `/admin/auth/user/`: searchable Users management, with verification status and presence of an avatar.
- `/api/profile/me/`: authenticated student dashboard data, including points, deduplicated solved problems and six recent submissions.
- `/api/profile/avatar/`: authenticated JPG/PNG/WebP upload and delete. Up to 2 MB input; server validates and crops to 256×256 JPEG.
- `/api/profile/avatar/<user_id>/`: public profile image used on the rankings page.
- `Миний самбар`: fifth Flutter tab with avatar editing, statistics, submissions and course shortcuts.
- Course/lesson Django Admin improvements (courses already existed; lessons can now also be edited separately).

**Important:** Avatar JPEG bytes are in PostgreSQL, not Render's filesystem. That avoids losing pictures when Render sleeps or redeploys, but requires a working, persistent PostgreSQL database with sufficient storage and backups. For a large student population later, switch to an image/object-storage service.

## 1. Merge the patch into your repo

1. Extract the ZIP to a temporary folder.
2. Copy the `backend` and `frontend` files from the patch into the existing repository at `C:\Users\dquat\Documents\GitHub\mandakhrank` (merge, do not delete other folders).
3. The patch was made against the previously shared auth + CMS-bridge + `docker_pull` code. Review any conflicts against newer local work before overwriting.
4. Leave `pc-judge`, its token, and all Gmail secrets unchanged.

Files to add/update:

```text
backend/catalog/models.py
backend/catalog/views.py
backend/catalog/admin.py
backend/catalog/profile.py [new]
backend/catalog/admin_overview.py [new]
backend/catalog/templates/catalog/admin_overview.html [new]
backend/catalog/migrations/0007_profileavatar.py [new]
backend/catalog/test_profile_dashboard.py [new]
backend/config/urls.py
backend/requirements.txt
frontend/lib/data.dart
frontend/lib/main.dart
frontend/lib/dashboard_screen.dart [new]
frontend/pubspec.yaml
```

## 2. Rebuild Flutter on Windows (PowerShell)

```powershell
cd "C:\Users\dquat\Documents\GitHub\mandakhrank\frontend"
flutter pub get
flutter build web --release --dart-define="API_BASE_URL=https://mandakhrank-api.onrender.com/api"
if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed. Do NOT deploy until this is fixed.' }
cd ..
New-Item -ItemType Directory -Force "backend\webapp" | Out-Null
Copy-Item "frontend\build\web\*" "backend\webapp\" -Recurse -Force
Test-Path "backend\webapp\index.html"
```

Then review and push changes:

```powershell
git status
git add backend/catalog/models.py backend/catalog/views.py backend/catalog/admin.py backend/catalog/profile.py backend/catalog/admin_overview.py backend/catalog/templates/catalog/admin_overview.html backend/catalog/migrations/0007_profileavatar.py backend/catalog/test_profile_dashboard.py backend/config/urls.py backend/requirements.txt frontend/lib/data.dart frontend/lib/main.dart frontend/lib/dashboard_screen.dart frontend/pubspec.yaml
git add -f backend/webapp
git diff --cached --stat
git diff --cached --check
# Inspect staging; do not commit .env, passwords, tokens, DATABASE_URL, or ZIP files.
git commit -m "Add student dashboard avatars and course administration"
git push
```

Existing Render start command includes `python manage.py migrate --noinput`. It should apply migration `0007_profileavatar` automatically. Keep **the existing PostgreSQL** (do not create a new one).

Run tests locally if Python dependencies are installed (Windows PowerShell):

```powershell
cd backend
python -m pip install -r requirements.txt
python manage.py test catalog.test_profile_dashboard
python manage.py check
```

Note: If `DATABASE_URL` is unset, these run on local SQLite. **Do not point tests at your production database.**

## 3. Admin login and registered students

- Management dashboard: `https://mandakhrank-api.onrender.com/admin/overview/`
- Full user list: `https://mandakhrank-api.onrender.com/admin/auth/user/`
- Admin login: `https://mandakhrank-api.onrender.com/admin/`

You must log in with a Django **superuser**. A normal student is not an admin, even if verified by email.

### If you have no superuser yet

Render Free web services do not include an interactive Shell. To create a superuser in your **existing production PostgreSQL**, connect from your Windows terminal using the database's **External Database URL** from Render Dashboard → your database → Connections. **Never share that URL: it includes your database password.**

In Windows PowerShell, from `mandakhrank/backend`, if Python is installed:

```powershell
# Get the connection URL from Render > database > Connections > External Database URL
# Read-Host enters the secret without putting it in your command history.
$env:DATABASE_URL = Read-Host 'Paste External Database URL (private)'
python -m pip install -r requirements.txt
python manage.py createsuperuser
Remove-Item Env:DATABASE_URL
```

**Verify `DATABASE_URL` points to your existing Render database BEFORE running `createsuperuser`.** Without `DATABASE_URL`, the command creates an admin in your local SQLite file instead and will NOT grant access to the live site. You can use a different username than your student account; don't edit existing records unnecessarily. If Render's database external connection isn't available, use a secure one-off management command deployment instead rather than guessing credentials. Never copy the external DB URL into GitHub.

## 4. Add a course and its lessons (no coding required)

1. Log in as a superuser at `/admin/`.
2. Select **Сургалтууд (Courses) → Add** or go directly to `/admin/catalog/course/add/`.
3. Enter:
   - **Нэр / Title:** e.g. `Python эхлэл`
   - **Чиглэл / Tag:** `Python`
   - **Түвшин / Level:** `Анхан шат` / `Дунд шат` / `Ахисан шат`
   - **Тайлбар / Description:** summary of the course
   - **Color:** blue, purple, cyan or green
   - **Нийтлэх (Published):** checked only when ready to appear publicly
4. Inside the same form's **Хичээлүүд (Lessons)** section click **Add another Lesson**. For every lesson enter `Title`, `Position` (1, 2, 3...), `Content`, and check that lesson's **Published** field.
5. Click **Save**.
6. Refresh the MandakhRank **Сургалтууд** tab. A published course displays only its published lessons.

**Example course:**

- Course title: `Python эхлэл`; tag `Python`; level `Анхан шат`
- Lesson 1 (`position=1`): `Хувьсагч`, content: `Python-д хувьсагч утга хадгална.\n\nx = 5\nprint(x)`
- Lesson 2 (`position=2`): `Оролт гаралт`, content: `name = input()\nprint("Сайн байна уу", name)`

Lesson text currently renders as selectable text preserving newlines; a full Markdown/editor experience is a possible future upgrade.

## 5. Test the student-facing features

1. Sign in to MandakhRank with a verified student account.
2. Open the new **Миний самбар** tab (or click the avatar icon).
3. Check points, solved count and recent submissions.
4. Select **Зураг оруулах**, choose a PNG/JPG/WebP below 2 MB. The picture should appear on the student dashboard and rankings; refreshing the page should keep it.
5. Try **Устгах** to delete the picture.
6. Sign in to Django Admin as a superuser, create a published course and published lesson, then view it in **Сургалтууд**.

If the avatar endpoint returns 404, verify Render deployed the updated `urls.py`. If it returns 500, inspect migration logs for `catalog.0007_profileavatar` and ensure Pillow installed. The upload is intentionally restricted to authenticated users.

## Security / operational notes

- No Gmail password or student authentication token should be exposed in source control.
- Avatar API checks the student's bearer token. Only the student can upload/delete their own image; images are publicly readable as leaderboard avatars.
- The admin overview is restricted to **superusers**, and should never be made public.
- Image validation is handled on the server; file extensions alone aren't trusted.
- Existing Docker judge and Gmail code are untouched by this patch.
- **Free Render PostgreSQL may have expiration / storage limitations; keep backups.**
- The patch must be built and run on the user's machine to verify Flutter compilation and complete Django integration tests. This packaging environment does not include the Flutter or Django SDKs.
