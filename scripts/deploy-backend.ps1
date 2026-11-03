param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
foreach ($file in @('render.yaml', 'backend/src/server.js', 'backend/render.env.example')) {
  if (-not (Test-Path -LiteralPath $file)) { throw "Missing deployment file: $file" }
}
npm.cmd --prefix backend run check
if ($LASTEXITCODE -ne 0) { throw 'Backend syntax checks failed.' }
npm.cmd --prefix backend test
if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed.' }
Write-Output 'Render deployment checks passed. No cloud resources changed.'
if (-not $CheckOnly) {
  Write-Output 'Deploy this repository as a Render Node Web Service: root backend; build npm ci; start npm start; health path /health.'
  Write-Output 'Set environment variables from backend/render.env.example and upload firebase-admin.json as a Render Secret File.'
  Write-Output 'Follow docs/FIREBASE_AND_RENDER.md. Firebase stays on Spark; do not deploy Cloud Functions.'
}
