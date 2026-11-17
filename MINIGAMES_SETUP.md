# MandakhRank — 3 touchscreen multiplayer minigames (pilot)

## What's included

1. **Олс таталт** — fill missing Python tokens to pull the rope; blue versus orange.
2. **Мэлхийн үсрэлт** — predict Python program output; animated frogs race on separate lanes.
3. **Кодын пуужин** — answer algorithms/Python questions; animated rockets race to the finish.

All game instructions, buttons and feedback are in Mongolian; language keywords and code remain in their native syntax. Flutter uses `CustomPainter`, `AnimationController`, `TweenAnimationBuilder`, and `AnimatedSwitcher` with large touch targets. No new Flutter dependencies.

Players choose **1 vs 1** or **teams of up to 3 per side**. A signed-in host creates a room and shares the six-character code. The guest enters that code in **Тэмцээнүүд → Тоглож эхлэх**. The host starts once each side has a participant. First side to reach **8 correct answers** wins; otherwise the higher score after **150 seconds** wins. Draws are possible. Progress synchronizes by polling Render every 1.2 seconds. **No WebSocket, CMS, Docker, or separate judge is required for these quiz games.**

### Important scoring boundary

These are *casual programming quizzes*. The Django server checks the correct choice and maintains the shared score, but question banks are shipped with the backend source. They **do not award official MandakhRank practice-problem points and do not change the coding leaderboard**. Do not use these mini-game scores for prizes or high-stakes tournament rankings without a dedicated anti-cheat review.

## Apply the patch

Use the contents of the ZIP as an **overlay**, not a fresh repository. The main files modified are:

- `frontend/lib/main.dart` — adds three games to the existing **Тэмцээнүүд** page.
- `frontend/lib/minigames_screen.dart` — all three responsive animated game screens, lobby, room joining, quiz controls.
- `backend/catalog/models.py`, `backend/catalog/migrations/0008_minigames.py` — persistent rooms, players and answer logs.
- `backend/catalog/minigames.py`, `backend/catalog/game_questions.py` — authenticated multiplayer API, server-side answer checking and 48 starter questions.
- `backend/config/urls.py` — adds the game API routes.
- `backend/catalog/admin.py` — optional game room monitoring in Django Admin.
- `backend/catalog/test_minigames.py` — Django API/permissions/regression tests.

**Before overwriting**: keep a backup or commit your current working app. Review differences in `main.dart`, `models.py`, `admin.py`, and `urls.py`, especially if you added custom features since the last dashboard/avatar release. Do not overwrite `.env`, `render.yaml`, `cms_bridge.py`, `serve.py`, or any `pc-judge` files; they are not part of this ZIP.

## Build Flutter and deploy

In **Windows PowerShell**, from the project's root:

```powershell
cd 'C:\Users\dquat\Documents\GitHub\mandakhrank'
cd frontend
flutter pub get
flutter build web --release --dart-define='API_BASE_URL=https://mandakhrank-api.onrender.com/api'
if ($LASTEXITCODE -ne 0) { throw 'Flutter compilation failed; do not deploy.' }
cd ..
New-Item -ItemType Directory -Force 'backend\webapp' | Out-Null
Copy-Item 'frontend\build\web\*' 'backend\webapp\' -Recurse -Force
Test-Path 'backend\webapp\index.html'
```

Then verify the staged files contain **no secrets**:

```powershell
git status
git add backend/catalog/models.py backend/catalog/admin.py backend/catalog/minigames.py backend/catalog/game_questions.py backend/catalog/migrations/0008_minigames.py backend/catalog/test_minigames.py backend/config/urls.py frontend/lib/main.dart frontend/lib/minigames_screen.dart MINIGAMES_SETUP.md
git add -f backend/webapp
git diff --cached --check
git diff --cached --stat
git commit -m 'Add Mongolian multiplayer touchscreen minigames'
git push
```

Render's existing startup command runs `python manage.py migrate --noinput` automatically. Confirm it applied `catalog.0008_minigames` in Render logs before trying the games. **Keep existing `JUDGE_ENGINE=docker_pull` and all Gmail settings unchanged.**

If you have a Django development environment, verify before push:

```bash
cd backend
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test catalog.test_minigames
```

The included tests cover account authentication, joining, starting, per-question scoring, replay rejection, 1v1 vs team capacities, and question-bank structure. In this packaging environment Python syntax and quiz-bank structure were checked; full Django tests and Flutter compilation could not run because those runtimes were unavailable. **Do not assume production readiness until your own builds/tests pass.**

## Test with two accounts/devices

1. Log in on your PC as User A.
2. Go to **Тэмцээнүүд → Тоглож эхлэх**. Select one of the three games and **1-ийн эсрэг 1**. Tap **Шинэ өрөө нээх**.
3. Copy the six-character room code.
4. Open MandakhRank on another device or private browser as **User B**. Go to the same section, paste the code and choose **Кодоор нэгдэх**.
5. On User A's screen select **Тоглоом эхлүүлэх**. Both should see questions and the same scoreboard.
6. Select correct and incorrect answers and verify that only correct ones increase the score, with a smooth animation.
7. Repeat in team mode, using up to three different accounts for each side.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Game endpoints return 404 | The new backend was not deployed; inspect Render's deployed Git commit and `config/urls.py`. |
| Server returns 500 with missing table | Migration `catalog.0008_minigames` has not been applied. |
| 401, 'Эхлээд нэвтэрнэ үү' | Log in with a verified active MandakhRank account. |
| Can't join, room full | Solo allows one account per side; teams allow three per side. |
| Opponent isn't updating | Check both browsers' internet and Render deployment; rooms poll every 1.2s. |
| Games disappear on refresh | Enter the room code again; signed-in members can rejoin the same room while it exists. |
| Existing Docker submissions stop | This patch should not touch `cms_bridge.py` or the PC worker; check `JUDGE_ENGINE=docker_pull` and that the worker terminal/Docker remain running. |

## Limits and next improvements

- First release supports **Python and general algorithms** questions. Add professionally reviewed questions for C++, JavaScript and Java later.
- 16 questions per player/game; all three game types currently use the same first-to-8 / 150-second rule.
- Database transactions and PostgreSQL row locks serialize scoring; duplicate question indexes are rejected.
- Screens poll instead of using WebSockets, so score changes appear with up to ~1.2s delay, then animate smoothly.
- Stale rooms are opportunistically deleted after seven days to limit database storage; users do not need to clean them manually.
- Games do not require the PC judge, but official Python code submissions **still require** the existing Docker judge on your PC.
- For high attendance or tournaments with prizes, add reviewed question pools, coordinated scheduling, stronger anti-cheat controls, monitoring, and load testing.
