param([string]$ApiBaseUrl = "https://mandakhrank-api.onrender.com/api")
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $projectRoot "frontend")
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw "Flutter tests failed" }
    flutter build web --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "Flutter web build failed" }
    $webTarget = Join-Path $projectRoot "backend\webapp"
    New-Item -ItemType Directory -Force $webTarget | Out-Null
    Copy-Item -Path ".\build\web\*" -Destination $webTarget -Recurse -Force
    Write-Host "Web build ready in backend/webapp. Commit it together with the source."
} finally { Pop-Location }
