# Health Broget Android release

Version 1.0.2 (build 3) applies the Health Broget name and new heart/leaf logo throughout the app, retaining compact loading indicators and the registration-name prefill fix. The same Flutter source supplies the hosted website and Android app.

## Build and signing

```powershell
node scripts/create-android-signing.mjs
.\scripts\build.ps1 -Target apk -Config config/production.local.json
```

The signing script preserves an existing identity and refuses to replace incomplete signing files. The private keystore is in `.local/signing/broget-release.p12`, and its passwords are in `android/key.properties`. Both paths are ignored by Git. Back up both privately: future APK updates must use the same signing identity. Never share either file with APK recipients.

The signed build output is `build/app/outputs/flutter-apk/app-release.apk`. The downloadable release asset is named `health-broget-1.0.2.apk` and has a companion SHA-256 file on GitHub Releases.

## App Check for shared APKs

The Android app uses Play Integrity. Its release SHA-256 signing fingerprint is registered with the Firebase Android app:

```text
6A:F5:6E:89:47:A8:F2:C8:4F:7A:A7:BB:E8:FA:53:FC:F0:4C:FE:E5:12:9D:F1:06:A8:F0:8A:0A:07:B4:A1:B0
```

Android App Check is configured for distribution outside Google Play: PLAY_RECOGNIZED and LICENSED are not required; MEETS_DEVICE_INTEGRITY is required, with one-hour tokens. App Check and Firebase user authentication remain enforced by the API. This follows [Firebase's settings for off-Play distribution](https://firebase.google.com/docs/app-check/android/play-integrity-provider). Certified Android devices with Google Play services are the intended targets; device attestation needs physical-device verification.

## Sharing and updates

Share the public APK download link from GitHub Releases, also linked on the website's Download page. Recipients can download the APK and allow installation from their browser when Android asks. They register their own Firebase accounts; no developer credential belongs in the APK.

Release compilation and signature verification do not replace physical-device checks for login, email verification, photo capture, AI analysis and reports. No Android device was connected during this release preparation.
