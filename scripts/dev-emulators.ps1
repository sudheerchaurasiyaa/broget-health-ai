$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$dataPath = Join-Path $projectRoot '.local\firebase-data'
$emulatorArgs = @('emulators:start', '--project', 'demo-broget', '--only', 'auth,firestore', "--export-on-exit=$dataPath")
if (Test-Path -LiteralPath (Join-Path $dataPath 'firebase-export-metadata.json')) { $emulatorArgs += "--import=$dataPath" }
Write-Output 'Starting local Auth and Firestore. Stop with Ctrl+C and wait for export to preserve test accounts and records.'
$ErrorActionPreference = 'Continue'
& firebase.cmd @emulatorArgs
$resultCode = $LASTEXITCODE
exit $resultCode
