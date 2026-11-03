param(
  [string]$WebConfig = '',
  [string]$SiteKey = '',
  [string]$ApiUrl = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$android = Get-Content -LiteralPath 'android/app/google-services.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$client = @($android.client | Where-Object { $_.client_info.android_client_info.package_name -eq 'com.broget.broget_ai' })[0]
if (-not $client) { throw 'google-services.json must contain com.broget.broget_ai.' }
$project = $android.project_info.project_id
if ($project -ne 'broget-health-ai') { throw 'Unexpected Firebase project. Review the Android configuration first.' }
$target = Join-Path $root 'config/production.local.json'
$settings = Get-Content -LiteralPath 'config/production.example.json' -Raw -Encoding UTF8 | ConvertFrom-Json
if (Test-Path -LiteralPath $target) { $settings = Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json }
$settings.APP_ENV = 'production'
$settings.USE_EMULATORS = 'false'
$settings.FIREBASE_PROJECT_ID = $project
$settings.FIREBASE_MESSAGING_SENDER_ID = [string]$android.project_info.project_number
$settings.FIREBASE_ANDROID_APP_ID = $client.client_info.mobilesdk_app_id
$settings | Add-Member -NotePropertyName FIREBASE_ANDROID_API_KEY -NotePropertyValue $client.api_key[0].current_key -Force
if (-not $settings.FIREBASE_AUTH_DOMAIN) { $settings.FIREBASE_AUTH_DOMAIN = "$project.firebaseapp.com" }
if ($WebConfig) {
  $web = Get-Content -LiteralPath $WebConfig -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($web.projectId -ne $project -or $web.appId -notmatch ':web:' -or -not $web.apiKey) { throw 'Web config must be the Firebase JSON configuration for this same project.' }
  $settings.FIREBASE_API_KEY = $web.apiKey
  $settings.FIREBASE_APP_ID = $web.appId
  $settings.FIREBASE_AUTH_DOMAIN = $web.authDomain
}
if ($SiteKey) { $settings.RECAPTCHA_SITE_KEY = $SiteKey }
if ($ApiUrl) { $settings.API_BASE_URL = $ApiUrl }
$settings | ConvertTo-Json | Set-Content -LiteralPath $target -Encoding UTF8
Write-Output "Prepared ignored client configuration for $project. Render environment values are documented in backend/render.env.example."
$missing = @('FIREBASE_API_KEY','FIREBASE_APP_ID','API_BASE_URL','RECAPTCHA_SITE_KEY') | Where-Object { -not $settings.$_ }
if ($missing) { Write-Output ('Still required before web production: ' + ($missing -join ', ')) }
