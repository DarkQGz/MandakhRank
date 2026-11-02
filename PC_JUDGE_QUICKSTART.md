# MandakhRank submissions directly from the website — free PC worker (pilot)

**Goal:** A student signs in to the existing MandakhRank website, selects any published practice problem, and clicks **Илгээж шалгуулах**. Django queues the submission in PostgreSQL. The *private* worker on your Ubuntu/WSL2 machine pulls the source **and that problem's existing hidden tests** from Render, evaluates them in separate restricted Docker containers, and reports an official status to Django. The Flutter page already polls submission history; you do **not** use the CMS website, import CMS contests, or assign `cms_task_name`.

This replaces the CMS connection **for initial Python-only practice judging**, not the website or database. **CMS is not used in this mode.** There is no RapidAPI billing or additional cloud server; your PC must be on. This is **not a production-security-audited solution for arbitrary public code** on your daily-use Windows PC.

## 1. Merge the patch into your current Git checkout (Windows)

Extract the ZIP *over the root* of `C:\Users\dquat\Documents\GitHub\mandakhrank`. It contains only:

- `backend/catalog/cms_bridge.py` — private authenticated queue endpoint, now supports Docker worker and secret testcase transfer;
- `backend/catalog/practice.py` — accepts submissions without CMS task names in Docker mode;
- `backend/catalog/management/commands/serve.py` — doesn't launch old Judge0 queue worker in Docker mode;
- `backend/catalog/test_docker_pull.py` — backend tests;
- `pc-judge/mandakhrank_pc_worker.py` — local Docker judge/Render connector;
- `pc-judge/test_mandakhrank_pc_worker.py` — portable worker tests;
- this guide.

**Important:** This is an overlay based on the CMS bridge version previously supplied. If you have made newer edits to those three backend files, review/merge the diff rather than blindly overwrite. Existing CMS migration `0006_cms_bridge.py` must already have been applied on Render (your prior `/api/judge/heartbeat/` result suggests the CMS bridge was deployed). Do **not** overwrite `settings.py`, `models.py`, Gmail files, or your live database.

In PowerShell:

```powershell
cd "C:\Users\dquat\Documents\GitHub\mandakhrank"
git diff -- backend/catalog/cms_bridge.py backend/catalog/practice.py backend/catalog/management/commands/serve.py
git status
git add backend/catalog/cms_bridge.py backend/catalog/practice.py backend/catalog/management/commands/serve.py backend/catalog/test_docker_pull.py pc-judge PC_JUDGE_QUICKSTART.md
git diff --cached --check
git diff --cached --stat
# Verify no secrets / .env files are staged before proceeding
git commit -m "Run Python submissions using private Docker pull judge"
git push
```

If your backend Python environment has Django installed, you can run `python manage.py test catalog.test_docker_pull` from `backend/` before pushing. On Render, confirm the new Git commit deploys successfully. **No Flutter rebuild is needed.**

## 2. Render environment

Open your existing `mandakhrank-api` service on Render → Environment:

```env
JUDGE_ENGINE=docker_pull
JUDGE_WORKER_TOKEN=EXACT_SAME_SECRET_ALREADY_IN_YOUR_UBUNTU_CMS_ENV
```

Reuse the same `JUDGE_WORKER_TOKEN` that your previous CMS bridge used. This is **not** `CMS_ADMIN_TOKEN`. Do not expose either secret. Keep Gmail, Django and database settings unchanged. The Judge0 RapidAPI variables and CMS task names are unused in `docker_pull` mode.

Save/deploy and check Render logs for errors. The worker checks an authenticated `/api/judge/status/` endpoint first to verify that the **new** code and `docker_pull` setting are live. It refuses to claim jobs from the old CMS-only backend.

## 3. Ubuntu outside the CMS container

Your ordinary Ubuntu prompt should start with `dquat@Sun` — **not** `cmsuser@...`.

Make sure Docker Desktop is running in Windows, with WSL Integration for Ubuntu enabled. In Ubuntu run:

```bash
docker info >/dev/null && echo "Docker works"
docker pull python:3.12-alpine
mkdir -p ~/mandakhrank-pc-judge
cp /mnt/c/Users/dquat/Documents/GitHub/mandakhrank/pc-judge/*.py ~/mandakhrank-pc-judge/
```

Use the same private `cms.env` file you already configured. The new worker only reads `MANDAKHRANK_API` and `JUDGE_WORKER_TOKEN`. It ignores `CMS_API_USER`, `CMS_ADMIN_TOKEN`, `CMS_BASE_URL` and language settings.

```bash
set -a
source ~/.config/mandakhrank/cms.env
set +a
cd ~/mandakhrank-pc-judge
python3 -m unittest -v
python3 mandakhrank_pc_worker.py --self-test
python3 mandakhrank_pc_worker.py --check
```

Expected local self-test: `Local Docker test passed: Accepted 2/2`.

Expected connection check: `Docker and MandakhRank Render authentication OK`.

If either fails, **stop and fix the error before running the continuous worker**. No public network ports need to be exposed on your PC.

## 4. Run the judge and submit on the MandakhRank WEBSITE

```bash
cd ~/mandakhrank-pc-judge
python3 mandakhrank_pc_worker.py
```

Leave the Ubuntu terminal and Docker Desktop running. Open your existing Render-hosted MandakhRank website in your browser, log in, select the addition problem and click **Илгээж шалгуулах** with:

```python
a, b = map(int, input().split())
print(a + b)
```

The **first** attempt should show `Queued`, then `Running`, then `Accepted 4/4` if the live addition problem still has its original four tests. The script logs the submission ID and verdict without logging source/testcases. Other correctly configured published MandakhRank problems also work automatically—no CMS import.

Test a wrong solution like `print(0)` and confirm a `Wrong Answer`. Confirm standings only update on `Accepted`.

## 5. Troubleshooting

- `HTTP 404` in `--check`: the new backend patch wasn't deployed (or the wrong URL).
- `Render is not running the new docker_pull bridge`: set `JUDGE_ENGINE=docker_pull` in Render and redeploy.
- `HTTP 401`: `JUDGE_WORKER_TOKEN` differs between Render and your private Ubuntu environment.
- `Docker unavailable or image missing`: start Docker Desktop, enable Ubuntu WSL integration and run `docker pull python:3.12-alpine`.
- `Queued` forever: the PC worker terminal must remain open, and PC awake; inspect its logs.
- `Judge Error`: inspect worker logs. A temporary Docker failure is retried up to three claims, then marked Judge Error.
- WSL may stop when Windows sleeps; this is not a 24/7 service.
- If your initial CMS ResourceService is still running with 16 idle workers, you can stop that CMS development process in its own terminal to free resources. It is **not needed** for this new worker. Do not delete your CMS database.

## What is and isn't included

- Included: native MandakhRank website submissions, PostgreSQL queue, private tests from Django, authenticated result reporting, one test per isolated Docker container, wall timeout, 128 MB memory limit, disabled container networking, non-root user, no writable image root, dropped Linux capabilities, bounded stdout/stderr, retry-on-worker-failure.
- Supported language: **Python 3 only**. No CMS problem mappings. No changes to Flutter UI needed.
- Not provided: CMS-based grading, C++/Java, exact CPU-time/memory usage in reports, reliable 24/7 availability, replay-proof idempotency, hardened multi-tenant isolation, high-availability job fleet, or production security certification.

**Security:** Do not open Docker's daemon socket, port 8888/8889 or any WSL inbound ports to the public internet. The worker makes outbound HTTPS requests only. Restrictive Docker flags reduce risk but containers on a WSL2 development machine **are not** a robust boundary for arbitrary hostile submissions. Keep it behind a small trusted test group until you migrate grading onto a dedicated, locked-down Linux machine or an audited sandbox such as properly deployed CMS/isolate. Microsoft's WSL security documentation says WSL itself is not a security boundary (https://wsl.dev/technical-documentation/security/).

**Token hygiene:** The CMS token shared earlier in chat should not be reused. Rotate it separately if you later resume CMS; this Docker worker doesn't use it.
