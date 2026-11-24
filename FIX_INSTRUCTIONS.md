# MandakhRank minigames Mongolian UTF-8 recovery

Replace only `frontend/lib/minigames_screen.dart` with the file in this package.
The replacement was reconstructed from the original Castle Battle source ZIP, preserving Cyrillic text, with the single compiler fix (`const ConstrainedBox(` -> `ConstrainedBox(`) applied.

IMPORTANT: Back up the existing file first if you have edited it. Do not use PowerShell `Get-Content` without `-Encoding UTF8` in Windows PowerShell 5.1 to read or rewrite Dart files containing Cyrillic.

PowerShell (run from project root after extracting the ZIP here):

```powershell
cd "C:\Users\dquat\Documents\GitHub\mandakhrank"
flutter --version
cd frontend
flutter build web --release --dart-define="API_BASE_URL=https://mandakhrank-api.onrender.com/api"
if ($LASTEXITCODE -ne 0) { throw "Build failed, stop." }
cd ..
Copy-Item "frontend\build\web\*" "backend\webapp\" -Recurse -Force
git add frontend/lib/minigames_screen.dart
git add -f backend/webapp
git diff --cached --stat
git commit -m "Restore Mongolian minigame text encoding"
git push
```

Do not commit until you review staged changes and ensure no secrets are included.
After Render deploys, hard refresh the page (Ctrl+Shift+R).
