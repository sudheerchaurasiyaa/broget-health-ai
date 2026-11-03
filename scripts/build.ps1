param(
  [ValidateSet('web','apk','appbundle')][string]$Target = 'web',
  [string]$Config = 'config/development.example.json'
)
$ErrorActionPreference = 'Stop'
function Invoke-CheckedNative {
  param([string]$Executable, [string[]]$Arguments)
  $previousPreference = $ErrorActionPreference
  try {
    # Windows PowerShell turns native stderr (including Flutter notices) into
    # error records. The process exit code determines whether a build failed.
    $ErrorActionPreference = 'Continue'
    & $Executable @Arguments
    $nativeExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  if ($nativeExitCode -ne 0) { throw "$Executable exited with code $nativeExitCode." }
}
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
Invoke-CheckedNative -Executable flutter -Arguments @('analyze')
Invoke-CheckedNative -Executable flutter -Arguments @('test')
Invoke-CheckedNative -Executable flutter -Arguments @('build', $Target, '--release', "--dart-define-from-file=$Config")
if ($Target -eq 'web') { Invoke-CheckedNative -Executable node -Arguments @('scripts/prepare-web.mjs') }
