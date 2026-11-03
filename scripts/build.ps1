param(
  [ValidateSet('web','apk','appbundle')][string]$Target = 'web',
  [string]$Config = 'config/development.example.json'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$settings = Get-Content -Raw -Encoding UTF8 -LiteralPath $Config | ConvertFrom-Json
$keys = $settings.PSObject.Properties.Name
if ($keys | Where-Object { $_ -match '(?i)(AI_API_KEY|SECRET|PRIVATE_KEY|PASSWORD)' }) { throw 'Client configuration must never contain server secrets.' }
if ($settings.APP_ENV -ne 'development') {
  foreach ($key in @('API_BASE_URL','FIREBASE_AUTH_DOMAIN','FIREBASE_PROJECT_ID','FIREBASE_MESSAGING_SENDER_ID')) {
    if ([string]::IsNullOrWhiteSpace($settings.$key)) { throw "Missing public configuration: $key" }
  }
  if ($Target -eq 'web' -and (-not $settings.FIREBASE_API_KEY -or -not $settings.FIREBASE_APP_ID)) { throw 'Web requires FIREBASE_API_KEY and FIREBASE_APP_ID.' }
  if ($Target -ne 'web' -and -not ($settings.FIREBASE_ANDROID_API_KEY -or $settings.FIREBASE_API_KEY)) { throw 'Android requires FIREBASE_ANDROID_API_KEY (or FIREBASE_API_KEY).' }
  $apiUri = [Uri]$settings.API_BASE_URL
  if ($settings.USE_EMULATORS -ne 'false' -or $apiUri.Scheme -ne 'https' -or $apiUri.IsLoopback -or $settings.FIREBASE_PROJECT_ID.StartsWith('demo-')) { throw 'Production must use attested HTTPS services and a real Firebase project.' }
  if ($Target -eq 'web' -and [string]::IsNullOrWhiteSpace($settings.RECAPTCHA_SITE_KEY)) { throw 'Web production requires App Check site key.' }
  if ($Target -ne 'web' -and [string]::IsNullOrWhiteSpace($settings.FIREBASE_ANDROID_APP_ID)) { throw 'Android production requires its Firebase application ID.' }
}
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
flutter build $Target --release "--dart-define-from-file=$Config"
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
if ($Target -eq 'web') { node scripts/prepare-web.mjs; if ($LASTEXITCODE -ne 0) { throw 'Web metadata generation failed.' } }
