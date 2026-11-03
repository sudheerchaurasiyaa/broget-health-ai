# Live Firebase and Render setup

BROGET uses Firebase Spark for email/password Authentication and Firestore, and a Render Node Web Service for its API. Do not deploy Firebase Cloud Functions for this setup. Photos are analyzed in memory and never saved. FCM background push delivery is not connected yet.

## 1. Firebase configuration already prepared

Project: `broget-health-ai`. Android package: `com.broget.broget_ai`.

`android/app/google-services.json` contains the Android registration. `config/firebase-web.local.json` contains the supplied public web registration. The generated `config/production.local.json` contains both platform configurations and sets `USE_EMULATORS=false`. Web and Android keys are handled separately. Backend URL and the web App Check site key still need to be supplied.

```powershell
cd E:\BROGET
.\scripts\configure-firebase.ps1 -WebConfig config/firebase-web.local.json
node scripts/check-firebase.mjs
```

You confirmed Email/Password Authentication is enabled and the default Firestore database exists. In Authentication settings, add your hosted web domain under Authorized domains and configure email verification/reset templates. The default Firebase-hosted email action handler can handle verification and password changes; BROGET requests the emails. Local emulator accounts are separate from real Firebase accounts: register again in the live app.

Publish the existing rules and indexes with your Firebase account:

```powershell
firebase.cmd login --reauth
firebase.cmd deploy --project broget-health-ai --only firestore:rules,firestore:indexes
```

Keep the existing server-only write rules for meals, reports and chat. The Render backend accesses these collections through the Admin SDK using its private credential.

## 2. Put the source in your Git repository

Render can deploy a connected GitHub/GitLab/Bitbucket repository. Commit source, `backend/package-lock.json` and `render.yaml`. Keep ignored files out of the commit: `backend/.env.local`, other backend env files, `config/*.local.json`, service-account JSON files, signing keys and build artifacts. A repository has not been created or pushed by this setup.

The local backend now loads `backend/.env.local`, preserving your existing AI key. Local development is unchanged:

```powershell
npm.cmd --prefix backend run dev
```

## 3. Create the Render backend

In Render, select **New → Web Service**, connect the repository and choose:

| Setting | Value |
|---|---|
| Runtime | Node |
| Root directory | `backend` |
| Build command | `npm ci` |
| Start command | `npm start` |
| Health check path | `/health` |
| Node version | `22` |

You can instead create a Blueprint using `render.yaml`. Either method still requires the private credential and AI key below. The blueprint defaults to a free instance. Free services sleep after idle periods, so the first API request may take about a minute; retry if the combined cold start and AI processing exceed the client timeout. Personal data stays in Firestore, not Render's ephemeral filesystem.

## 4. Add environment variables and the private credential

Use `backend/render.env.example` as the reference. Set these in Render → Environment:

```text
NODE_VERSION=22
APP_ENV=production
GCLOUD_PROJECT=broget-health-ai
ALLOWED_ORIGINS=https://broget-health-ai.web.app,https://broget-health-ai.firebaseapp.com
AI_MODEL=gemini-3.5-flash
AI_API_KEY=<your AI key, entered privately in Render>
GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/firebase-admin.json
```

Use the same working AI_MODEL value as your local backend if you change models. USDA_API_KEY is optional for database search; photo estimates and manual food entry do not depend on it. Do not set emulator host variables. Render supplies PORT automatically.

In Firebase → Project settings → Service accounts, generate a new private key for this project. In Render → Environment → Secret Files, add a file named exactly `firebase-admin.json` and paste the downloaded JSON there. Do not paste it in chat or commit it. GOOGLE_APPLICATION_CREDENTIALS points the Admin SDK to that secret file. The service account needs Firestore data access, Firebase Authentication user administration and Firebase App Check token verification permissions. Use a dedicated service account with appropriate roles for ongoing operation.

Deploy. Visit the service's URL followed by `/health`, for example `https://YOUR-SERVICE.onrender.com/health`. Expect `{"status":"ok"}`. This checks HTTP startup; authenticated API calls must also verify the Firebase credential, App Check and database access.

## 5. Register App Check

The API verifies Firebase ID tokens and App Check tokens. Keep both checks enabled.

- Web: Firebase → App Check → select the Web app → register reCAPTCHA v3 for your hosted domains. Its **site key** is public and belongs in RECAPTCHA_SITE_KEY. Register the secret with Firebase, not the Flutter app.
- Android: add the signing certificate's SHA-256 fingerprint under the Android app, then register Play Integrity in App Check. Configure the Play Integrity settings for your intended distribution, including sideloaded APKs if applicable. Check this on a physical device.
- For localhost or emulator testing against live services, follow the App Check debug-provider workflow; the existing emulator configuration remains the easiest local development option. Do not weaken production checks or add localhost to a production reCAPTCHA key.

Start with App Check metrics, verify working tokens, then enable enforcement for Firestore and other supported Firebase products. The custom Render API enforces tokens independently.

## 6. Set the URL, build and host the client

```powershell
.\scripts\configure-firebase.ps1 -WebConfig config/firebase-web.local.json -ApiUrl https://YOUR-SERVICE.onrender.com -SiteKey YOUR_RECAPTCHA_V3_SITE_KEY
.\scripts\build.ps1 -Target web -Config config/production.local.json
firebase.cmd deploy --project broget-health-ai --only hosting
```

Use the Render service URL without a trailing slash and without `/api`; the standalone server exposes `/chat`, `/analyze`, etc. directly. The Cloud Functions URL format is not used here. If using a custom frontend domain, add its exact origin to ALLOWED_ORIGINS in Render and register the domain in Firebase Authentication and reCAPTCHA.

Android production builds also need `android/key.properties` and the backed-up private signing key:

```powershell
.\scripts\build.ps1 -Target apk -Config config/production.local.json
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`. Native Firebase Gradle plugins are enabled for builds explicitly using USE_EMULATORS=false; emulator builds retain demo configuration isolation.

## 7. Verify the live flows

1. Register using an email address you control and finish onboarding.
2. Open the verification email, return to Overview and select **I have verified**. BROGET refreshes the Firebase token so the API sees the new verification status.
3. Sign out and sign in again.
4. Request a password reset, open its email link, choose a new password and sign in using that password.
5. Add a meal, scan a photo, send an assistant message and open reports; confirm they appear in your own Firestore account.
6. Sign into a second account and confirm it does not see the first account's content.

Registration remains successful if verification delivery needs a retry; Overview offers another verification email. Reset requests show the same result for nonexistent addresses. App Check registration, reset-email delivery, Render deployment and physical-device checks require live configuration and have not been certified by local unit tests.

References: [Render Express deployment](https://render.com/docs/deploy-node-express-app), [secret files](https://render.com/docs/configure-environment-variables), [free service behavior](https://render.com/docs/free), [Firebase Admin credentials](https://firebase.google.com/docs/admin/setup), [Flutter App Check](https://firebase.google.com/docs/app-check/flutter/default-providers), [debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider).
