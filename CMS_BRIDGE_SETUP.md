# MandakhRank → CMS (PC pull-worker) — pilot integration

**Status:** Django-side queue + local worker source is provided. This has **not** been exercised against your live Render instance or CMS Docker on your PC. Start with a **private test account and one matched problem**. CMS Docker development mode is privileged and not safe for public competition workloads on your normal PC.

## Architecture

- Browser → Django/Render: ordinary `/api/submissions/` as before.
- Private PC bridge → Django/Render: HTTPS `/api/judge/claim/`, `/api/judge/heartbeat/`, `/api/judge/complete/`, `/api/judge/release/` with a dedicated bearer secret.
- Private PC bridge → `http://127.0.0.1:8888`: CMS **ContestWebServer API**, using a CMS admin impersonation token held on the PC only.
- CMS internally handles compiling, sandboxed grading and scoring. Do NOT expose CMS/PostgreSQL/Docker ports or `/api/judge/` secret publicly.
- Bridge supports **Python 3 only**, **one source-file CMS Batch task** (other task types unsupported); one worker recommended.

## A. Make CMS grade a standalone test (inside your existing Docker setup)

If `cmsContestWebServer` is running manually, stop it with Ctrl+C so ResourceService can bind the same port.

**CMS container shell 1:**

```bash
cmsLogService
```

**Open a second Ubuntu terminal:**

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker exec -it YOUR_CMS_CONTAINER_NAME bash
cmsResourceService -a
```

Choose your imported contest when prompted. Leave both terminals running. ResourceService reads `~/cms/etc/cms.toml` and starts the **configured** worker, evaluation, scoring and web services; verify in the LogService output. You can create an admin user in an additional shell with `cmsAddAdmin admin`, which prints the initial password. Visit `http://localhost:8889` (admin) and `http://localhost:8888` (contestant). Verify one real submission receives a complete testcase result **before** continuing.

The dev container and CMS internals are not public web services. Official docs: https://cms.readthedocs.io/en/latest/Running%20CMS.html

## B. Prepare one real CMS task

**CMS sample `con_test` problems do not match MandakhRank's existing problems.** Import or create a CMS **Batch** problem with the same statement, stdin/stdout behavior, **the same expected outputs and hidden testcases** as a MandakhRank problem. Its `submission_format` must contain exactly one source file with `.%l` (e.g. `main.%l`). Enable **Python 3 / CPython** in the CMS contest's allowed languages. CMS may default to C/C++/Pascal, so enabling Python matters.

Recommended: prepare problem data in the official Italian contest format, with `task.yaml`, `statement/statement.pdf`, `input/input0.txt`..., `output/output0.txt`... and import with `cmsImportContest` (or use the CMS admin to build a task and dataset). Official format: https://cms.readthedocs.io/en/latest/External%20contest%20formats.html

The CMS task name (for example `addition`) must be entered in the Django Admin on the corresponding MandakhRank **Problem → CMS task name**. **Do not map an addition problem to the sample `batch` test task unless its tests are actually identical.** All unmapped problems will intentionally reject new submissions with HTTP 409 in CMS mode.

For first validation, use an actual matching task in a CMS contest and a private MandakhRank test user. For general practice, a long-running CMS practice contest or admin phase overrides are required. This bridge uses admin phase overrides, but actual permissions, CMS task settings and language availability must be verified.

## C. Install patch in your current MandakhRank Git repo

The accompanying ZIP is an **overlay**, not a replacement for your live repo. Extract its `backend/`, `cms-bridge/`, and this document into your existing MandakhRank root, merging folders. **Review the changed files before committing**, especially if you have changed them since the previous ZIP. Keep all existing Gmail settings and database data.

From PowerShell in your repo:

```powershell
git status
git add backend/catalog/models.py backend/catalog/practice.py backend/catalog/admin.py backend/catalog/cms_bridge.py backend/catalog/test_cms_bridge.py backend/catalog/migrations/0006_cms_bridge.py backend/catalog/management/commands/serve.py backend/config/settings.py backend/config/urls.py cms-bridge CMS_BRIDGE_SETUP.md
git diff --cached --stat
git commit -m "Add secure CMS pull worker bridge"
git push
```

In Render → existing `mandakhrank-api` → Environment, add:

- `JUDGE_ENGINE=cms_pull`
- `JUDGE_WORKER_TOKEN=<generate a random 32-byte secret locally, keep private>`

Example secure secret generator in **Ubuntu**:

```bash
python3 -c 'import secrets;print(secrets.token_hex(32))'
```

Paste the same secret into Render and your Ubuntu private env file, **never into your repo**. Your Render start command stays `python manage.py migrate --noinput && python manage.py seed_problems --if-empty && python manage.py seed_courses --if-empty && python manage.py serve`. In `cms_pull` mode, the Render web process deliberately **does not run** the old Judge0 worker. Existing `JUDGE0_URL` is unused in this mode; removing old provider keys is recommended.

Confirm the Render deployment completed its migration successfully and `/admin/` shows `CMS task name` for practice problems. Keep `GMAIL_*` settings unchanged.

## D. Configure CMS admin impersonation securely on your PC

In the CMS container inspect, but **do not post**, the `contest_admin_token` setting:

```bash
grep -n 'contest_admin_token' ~/cms/etc/cms.toml
```

Choose a sufficiently long random secret for this setting if it is missing or uses a default. Restart CMS services after editing the config. This is an **extremely privileged CMS token**: it enables impersonation and unfiltered results; **only keep it in the PC's private config**. Do not put this token in Render or GitHub. `CMS_API_USER` must be a user enrolled in the CMS contest (e.g. `u1` after sample import); for a new practice contest, create a dedicated CMS bridge user and its participation.

CMS official API: https://cms.readthedocs.io/en/latest/API.html

## E. Start the private worker on Ubuntu (outside CMS container)

First copy the `cms-bridge` folder from your Windows repo into your WSL home directory:

```bash
mkdir -p ~/mandakhrank-bridge ~/.config/mandakhrank
cp /mnt/c/Users/dquat/Documents/GitHub/mandakhrank/cms-bridge/*.py ~/mandakhrank-bridge/
nano ~/.config/mandakhrank/cms.env
```

Set **your own values**:

```bash
MANDAKHRANK_API='https://mandakhrank-api.onrender.com'
JUDGE_WORKER_TOKEN='YOUR_SAME_RENDER_WORKER_SECRET'
CMS_BASE_URL='http://127.0.0.1:8888'
CMS_API_USER='u1'
CMS_ADMIN_TOKEN='YOUR_PRIVATE_CMS_CONTEST_ADMIN_TOKEN'
CMS_LANGUAGE='Python 3 / CPython'
CMS_JOB_TIMEOUT='300'
```

Save. Protect the file and load it into the current shell:

```bash
chmod 600 ~/.config/mandakhrank/cms.env
set -a
source ~/.config/mandakhrank/cms.env
set +a
cd ~/mandakhrank-bridge
python3 cms_bridge_worker.py --check
```

This checks CMS authorization and prints task names. Once the matching task is visible and Docker grading works, start polling Render:

```bash
python3 cms_bridge_worker.py
```

Leave this terminal open. When a user submits a matched problem, expect `Queued → Running → Accepted/Wrong Answer/...`. Run tests locally with `python3 -m unittest -v` inside `~/mandakhrank-bridge`.

**Important:** If your source file's field name, allowed CMS language, contest phase or scoring mode does not match the CMS API, the worker may return HTTP 422 or no testcase data. Adjust the CMS **task settings** and test against `/api/task_list`; do not replace CMS with `subprocess` in Django.

## F. Operational limitations

- The CMS Docker **development** container may be privileged and its sandbox runtime needs independent verification under WSL2. Do not expose this setup to the public or treat it as competition-grade without security and stress testing.
- **No automatic CMS problem synchronization:** the Python code and CMS test cases are judged by CMS; Django's existing hidden testcase snapshot is not sent to CMS. Import a **matching CMS task** per problem and map each task name in Django Admin.
- CMS user `u1` in the sample contest is for testing only; production should use a private bridge participation and separate official contest database.
- **Retries:** after worker failure the Django submission is retried up to three times; the CMS submission ID is saved when possible. A crash between CMS acceptance and saving that ID can still create a duplicate CMS entry. Do not use for high-stakes ranking without stronger idempotency and audit trails.
- **Status:** initial outcome mapping recognizes standard text from the CMS detail API; scoring variations, compile failures without testcase details, and multi-file tasks need further support. Never assume `Accepted` until an actual submission is validated.
- A home PC is not 24/7 hosting. When offline, Django queues jobs, but user requests may hit queue limits until the PC is back. WSL sleep / Docker restarts will interrupt grading.
- Do not expose `8888`, `8889`, `5432`, or the Docker socket publicly. CMS's own internal services have no network authentication and must remain isolated.
- The bridge uses **Python** submissions only. Add a frontend language selector, language field in Submission, and language-specific CMS submission mappings before supporting C++.

## G. First deployment checklist

1. `cmsLogService` shows real EvaluationService/Worker activity, and a CMS sample problem receives a verdict.
2. You have a **new matched Batch problem and dataset** in CMS; the equivalent MandakhRank Problem has the correct `cms_task_name`.
3. Django migration 0006 ran on Render. `JUDGE_ENGINE=cms_pull` and `JUDGE_WORKER_TOKEN` are configured privately.
4. `python3 cms_bridge_worker.py --check` lists your CMS task in Ubuntu.
5. `python3 cms_bridge_worker.py` logs a claimed job and eventually a result on your private test account.
6. Your normal MandakhRank login, Gmail registration, and leaderboard still function.
