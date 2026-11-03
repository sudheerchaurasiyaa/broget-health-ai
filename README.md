# BROGET AI

One Flutter application for Android and responsive Web: public pages, Firebase authentication, onboarding, nutrition profile and deterministic targets, photo recognition, optional reference objects, nutrition lookup, editable confirmed meals, dashboard, daily/weekly/monthly reports, assistant, settings and account deletion. **Photo storage is coming soon.** Only Auth and Firestore are required; scans process photos without saving them.

Riverpod owns state; GoRouter owns guarded navigation. Firestore repositories supply private reads; authenticated backend endpoints validate all meal mutations. The same Node API runs locally without deployed paid Cloud Functions and as a Firebase HTTPS function in production. Provider credentials never enter Flutter. No fake data is used in application flows.

Read [Firebase Spark and Render deployment](docs/FIREBASE_AND_RENDER.md), [architecture and tree](ARCHITECTURE.md), [API contract](docs/API.md), [security boundaries](docs/SECURITY.md), [context/report/reminder design](docs/CONTEXT_AND_REMINDERS.md) and [verification record](docs/VALIDATION.md).

## Requirements

- Flutter 3.47.5 / Dart 3.13.4, the installed validation toolchain. Use committed pubspec.lock.
- Node 22 for deployment; local tests also run on installed Node 23.6.0.
- Firebase CLI 15.28.2 or compatible, Java 21+ for emulators, Android SDK/JDK for APKs.
- Server-only multimodal AI credential and supported model ID, plus a USDA FoodData Central key. Manual label entry works without either API key.
- Android application ID: `com.broget.broget_ai`.

## Local development without billing

Run from PowerShell in `E:\BROGET`. Install once:

```powershell
flutter pub get
npm.cmd --prefix backend ci
if (-not (Test-Path backend/.env.local)) { Copy-Item backend/.env.example backend/.env.local }
```

The supplied AI key is already configured in ignored `backend/.env.local`. Its configured model must pass real structured generation checks, not just appear in a model listing: listed models can still reject generation for an account. To configure another machine, fill AI_API_KEY and AI_MODEL there. USDA_API_KEY is still needed for online nutrition search; manual label entry works without it. Keep APP_ENV=development and the demo Auth/Firestore emulator hosts until real Firebase configuration is supplied. Keys stay in the backend, never in Dart defines.

Do not overwrite an existing backend/.env.local with the example, since that would erase locally configured credentials. For future setup, copy the example only if the local file does not exist. Recheck credentials with `npm.cmd --prefix backend run check:ai`.

Use three terminals:

```powershell
# Terminal 1
.\scripts\dev-emulators.ps1
```

```powershell
# Terminal 2
npm.cmd --prefix backend run dev
```

```powershell
# Terminal 3
flutter run -d chrome --web-port 5173 --dart-define-from-file=config/development.example.json
```

The emulator UI is http://localhost:4000. Auth prints verification/reset links. Create an account, complete onboarding, add a labeled food or search a nutrition source, then scan/review/save and inspect reports. The startup script imports prior exports from ignored .local/firebase-data and exports on a normal Ctrl+C shutdown; wait for export to finish. Killing the process abruptly can still lose unexported test data. Never use production health records for local development.

Reports now include daily, weekly, monthly and yearly views. They use a fixed journal timezone and server-maintained daily totals; older meals are indexed in resumable pages. Yearly views show monthly averages with month drill-down. Settings has user-confirmed assistant notes and reminder preferences. The assistant retrieves bounded recent conversation and relevant nutrition summaries, not the full account history. A private Reminders inbox records eligible prompts and user acknowledgments; FCM background push delivery is not yet connected. The service evaluates in-app reminders after profile load and when the inbox is refreshed.

Android emulator (`flutter devices` lists IDs):

```powershell
flutter run -d YOUR_DEVICE_ID --dart-define-from-file=config/development.example.json --dart-define=EMULATOR_HOST=10.0.2.2 --dart-define=API_BASE_URL=http://10.0.2.2:8787
```

A physical phone needs your PC's private LAN IP for both overrides and firewall access to 8787/8080/9099. Emulators/server bind to all interfaces for this workflow: use a trusted private network and never expose development ports publicly. Android uses the system camera flow and Photo Picker, with no broad storage/camera permissions. Photo selection remains available if capture fails; interrupted Android picking is recovered on the scanner page.

## Configuration

Copy an example to ignored `config/*.local.json`; load it with --dart-define-from-file. The client does not load .env files.

| Key | Purpose |
|---|---|
| APP_ENV | development, staging or production |
| USE_EMULATORS | true only for isolated local development |
| EMULATOR_HOST | localhost, 10.0.2.2, or private PC IP |
| API_BASE_URL | Local development API or deployed HTTPS function URL, no trailing slash |
| FIREBASE_API_KEY | Public Firebase client key, never an AI key |
| FIREBASE_APP_ID | Firebase Web application ID |
| FIREBASE_ANDROID_APP_ID | Firebase Android application ID |
| FIREBASE_PROJECT_ID | Project ID |
| FIREBASE_MESSAGING_SENDER_ID | Public sender identifier |
| FIREBASE_AUTH_DOMAIN | Authorized Firebase auth domain |
| RECAPTCHA_SITE_KEY | Production Web App Check Enterprise/Fraud Defense public site key |
| APP_DOWNLOAD_URL | Optional real HTTPS APK URL; empty hides download button |

Server variables are documented in backend/.env.example and backend/production.env.example. ALLOWED_ORIGINS is a comma-separated list of exact origins with no trailing slash. Authentication and quotas are independent of CORS. Firebase client identifiers are public; AI/USDA keys and service-account credentials are secrets.

The checked build script rejects secrets in client config and rejects emulator/HTTP/demo settings for production/staging. The app also has a runtime guard. CI and distribution must use scripts/build.ps1; raw Flutter commands can bypass the script's build-time checks.

## Firebase setup

Create separate staging and production projects, register Android/Web apps, enable email/password auth, set a 12-character password policy and email enumeration protection, configure authorized domains/action emails, and create Firestore in the intended region. Firebase Storage is not required or initialized. Its dormant deny-all rules are kept as a future safeguard.

Copy public Firebase identifiers into local client config. FirebaseOptions are supplied explicitly. For production native Analytics/Crashlytics service configuration and symbol upload, run FlutterFire CLI against your project and apply its Android service configuration/Gradle integration. Keep this project's explicit Dart configuration as the source of client options. Optional analytics/crash collection starts disabled.

Register Android Play Integrity with release SHA-256 fingerprints, and Web App Check Fraud Defense (reCAPTCHA Enterprise) for real domains. Use the same public Enterprise site key in Firebase App Check and the client configuration. Enable Firestore App Check enforcement and Authentication enforcement where supported after validating client tokens. The production backend independently verifies App Check. Configure appropriate Play Integrity settings for sideloaded APKs and validate on intended devices.

```powershell
firebase.cmd login
firebase.cmd deploy --project YOUR_PROJECT_ID --only firestore:rules,firestore:indexes
```

Queries use automatic single-field timestamp indexes; no composite indexes are required. The default firestore.indexes.json works on Spark without billing. Optional cleanup TTLs for structured analysis, quotas and nutrition searches are in firestore.indexes.blaze.json and require billing. Expired scan results are never served after their logical expiry. On Spark, delete expired cache/quota records with a privileged maintenance process. Images are never persisted, including as Firestore base64 fields.

## Nutrition and regional foods

Meals offers **Scan meal photo** and **Add manually**. The scanner supports Android camera capture and photo uploads. Photo analysis prefills estimated foods, portions, calories and macros, suggests a meal type and uses the photo-selection time. One review dialog lets users edit the meal type, date/time, each food, portions and nutrient values before confirming. Photos are processed without saving them; estimates are approximate, especially for hidden oils and recipes.

Nutrition search separately uses USDA FoodData Central Foundation/SR Legacy/FNDDS and an administrator-managed regional Firestore catalog. Search Indian foods such as roti, chapati, dosa, idli, sambar, dal and biryani; exact availability and recipes depend on the configured sources. AI photo estimates retain distinct attribution from database matches and user-edited values. Users can replace estimates with attributed label values or database matches.

Import reviewed, licensed regional data with Application Default Credentials (or set FIRESTORE_EMULATOR_HOST for local import):

```powershell
$env:GCLOUD_PROJECT = 'YOUR_PROJECT_ID'
node scripts/import-foods.mjs PATH_TO_REVIEWED_CATALOG.json
```

Input: JSON array of objects with id (lowercase slug), searchTerms (normalized exact aliases), and food {name, attribution, per100g {calories, protein, carbs, fat, fiber}}. Fiber may be null. Values must come from a reliable source. Every row is validated; no sample nutrients are shipped as real data. Admin API maintenance requires a server-assigned admin custom claim. No client can grant roles.

## Production backend

**Current deployment choice:** keep Firebase on Spark and host the Node API on Render. Follow [the Firebase and Render guide](docs/FIREBASE_AND_RENDER.md). The hosted entry point is `backend/src/server.js`; `npm start` runs it, while `npm run dev` keeps using the local Firebase emulators. `scripts/deploy-backend.ps1 -CheckOnly` validates the backend without changing cloud resources. The Cloud Functions instructions below describe an optional Blaze alternative and are not required for the selected Render setup.

Cloud Functions deployment requires billing. Until enabled, use the complete local server. The UI/service contract stays the same; there are no client secrets to migrate.

Copy backend/production.env.example to ignored backend/.env.YOUR_PROJECT_ID and fill project, exact origins and a supported multimodal model ID. Store credentials in Secret Manager:

```powershell
firebase.cmd functions:secrets:set AI_API_KEY --project YOUR_PROJECT_ID
firebase.cmd functions:secrets:set USDA_API_KEY --project YOUR_PROJECT_ID
firebase.cmd deploy --only functions --project YOUR_PROJECT_ID
```

Put the returned api HTTPS function URL in API_BASE_URL. Set budgets/alerts, least-privilege runtime permissions, cleanup policies and logging retention. Server quotas are enforced transactionally. maxInstances limits concurrency, not total spending. The local server requires Auth/Firestore emulators and APP_ENV=development; production refuses emulator hosts.

## Checks

```powershell
flutter analyze
flutter test
npm.cmd --prefix backend run check
npm.cmd --prefix backend test
firebase.cmd emulators:exec --config firebase.test.json --project demo-broget --only auth,firestore "npm.cmd --prefix backend run test:rules"
npm.cmd --prefix backend audit
```

The test config isolates emulator ports. Tests cover target safeguards, local date/report boundaries, malformed AI/nutrients/images, route guards, responsive layouts, strict schemas, arithmetic, identity/safety filtering, cross-user denial, profile/settings, deletion locks, token authentication, quotas, idempotent meals, disabled photo storage and account deletion. Additional tests exercise legacy migration, date moves/deletion, leap-year summaries, bounded verified chat memory, request retries, reminder consent/quiet hours, deduplicated inbox entries and recorded responses.

Fonts and licenses are bundled. Review golden changes before intentionally running flutter test --update-goldens. Actual inference, real App Check, physical camera behavior, signing, store approval and live-service failures require configured service/device validation.

## Builds and deployment

```powershell
.\scripts\build.ps1 -Target web -Config config/production.local.json
firebase.cmd deploy --only hosting --project YOUR_PROJECT_ID
```

The build generates public per-route HTML metadata. Hosting clean URLs/fallback rewrites support refresh, back/forward and deep links. Private routes carry noindex headers/metadata. The browser contains the full signed-in product. PWA manifest, branded icons and a limited public-only service worker are included; API traffic and personal data are not service-worker cached. Offline Firebase caches may be readable; AI and meal mutations require a connection.

Release signing is mandatory and never falls back to a debug key. Generate/back up your private signing key using your organization's process, copy android/key.properties.example to ignored android/key.properties, and fill real local values:

```powershell
.\scripts\build.ps1 -Target apk -Config config/production.local.json
.\scripts\build.ps1 -Target appbundle -Config config/production.local.json
```

Artifacts: build/app/outputs/flutter-apk/app-release.apk and build/app/outputs/bundle/release/app-release.aab. Configure APP_DOWNLOAD_URL only after hosting a built signed APK. Version comes from pubspec.yaml/package metadata. For a local test APK, use flutter build apk --debug with the same defines as the emulator run command; it is a development artifact.

## Branding

The supplied original PNGs are preserved in `assets/branding/`: the full logo retains transparency, and the app logo retains its background. Run `node scripts/generate-icons.mjs` after replacing the originals to regenerate Android launcher/splash artwork, web icons and the compact Flutter asset. Rebuild the APK to update the installed launcher icon.

## Troubleshooting

- Configuration state: verify public Firebase identifiers, platform app ID, backend URL and App Check registration.
- Manual meals cannot save: start the local API as well as Firebase emulators. Mutations always use server validation.
- Assistant/search unavailable: supply server keys/model, verify quotas, or use manual labels. Raw provider errors are not exposed.
- After changing backend code or backend/.env.local, stop the API with Ctrl+C and restart `npm.cmd --prefix backend run dev`. The local process reads its configuration at startup. Run `npm.cmd --prefix backend run check:ai` to test actual generation; model-list access alone does not prove inference availability. Temporary overload retries are bounded and configuration/model failures are surfaced separately.
- Local Firebase Installations errors: Analytics/Crashlytics have no emulator and must not initialize against the demo key. This app skips those SDKs entirely in emulator mode; fully reload the browser after updating startup code.
- Web CORS: use port 5173 and include its exact origin in ALLOWED_ORIGINS.
- Android network: use 10.0.2.2 for the standard emulator. Only the debug manifest permits HTTP.
- Cross-drive Kotlin cache failures: keep the non-incremental/in-process Gradle settings when SDK/package caches are on C: and the project is on E:.
- Emulator port conflict: use the isolated test config or inspect the existing process before stopping it; do not terminate unrelated services.
- Deletion needs fresh sign-in: settings reauthenticates with the password. Retry interrupted deletion after signing in; access stays locked during cleanup.
- No calorie target: minors, unspecified sex and special care needs intentionally receive no generic calorie prescription.

Before real-user release, configure live services, fill the operator-specific privacy/terms details, review processor/retention agreements, validate physical Android devices and real attestation, exercise the configured model with safety cases and complete release review. Source generation and local tests do not certify production readiness, medical suitability or legal compliance. No deployment or store listing is implied.
