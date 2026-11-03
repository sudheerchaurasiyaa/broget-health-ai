# Verification record

Validation performed on 28 October 2026 in E:\BROGET using Flutter 3.47.5, Dart 3.13.4, Node 23.6.0, Firebase CLI 15.28.2 and local Firebase emulators. Cloud deployment uses Node 22.

Passed checks:

- Flutter domain and responsive widget suite: 10 tests, including 320/768/1440 pixel layouts and reviewed golden images with bundled typography.
- Backend strict-schema, arithmetic, identity and safety suite: 5 tests.
- Firebase emulator integration suite: authentication/ownership, privileged-field rejection, deletion locks, profile/settings, unauthorized requests, server quotas, 12-food meals, idempotent mutations, disabled photo storage and account deletion without a bucket.
- Web release compilation and Android debug APK compilation. The initial Kotlin cross-volume incremental-cache issue was corrected with non-incremental in-process Kotlin compilation.
- npm dependency audit reported zero vulnerabilities after patched Firebase/image-processing dependencies and a compatible gRPC override.
- The original model-list check was insufficient: the listed model rejected actual generation with HTTP 404. It was replaced in local server configuration with a model that returned real, schema-valid chat and food-schema responses. check:ai now exercises actual generation. This does not establish inference quality or safety behavior.
- Regression tests cover bounded overload/network retries, unavailable model errors, invalid JSON, rate limiting, configuration errors, safety blocks and exclusion of internal thought parts. Emulator startup skips Analytics/Crashlytics so demo Firebase identifiers do not generate live Installations calls. Account initialization is deduplicated per UID.

Current configuration:

- User's AI credential is only in ignored backend/.env. It is not in client code, public defines or example files.
- Firebase project identifiers have not been supplied. Local demo Auth/Firestore emulators remain configured; no live Firebase connection or deployment has occurred.
- Firebase Storage has been removed from active dependencies, initialization, mutations, emulator requirements and deployment commands. Photo storage shows coming soon. Photos are sent transiently for analysis; Firestore stores only structured results and meal records.
- USDA nutrition API credentials are still required for online food search. Manual attributed label entry is available.
- No production signing key, hosted APK URL or store listing has been supplied. Production release signing and service configuration are deliberately required.

2 November 2026 update: added transactional daily summaries, resumable legacy indexing, IANA journal timezones, calendar-year reports, server-owned chat turns with bounded context retrieval, explicitly confirmed notes, and a private reminder/event inbox. The expanded tests cover aggregate correction across date moves and retries, cross-user isolation, leap years/DST, profile exclusions and opt-in reminder history. FCM delivery remains unconnected and is never marked sent or delivered. See the new context/report/reminder design document for exact limits and migration behavior.

For this update, Flutter analysis and 14 Flutter tests passed, including Yearly report render checks at 320 and 1440 pixels. All 15 backend unit tests and nine Auth/Firestore emulator integration tests passed. The Web release compiled successfully. Android verification encountered a Gradle dependency-network stall and is being retried separately; the earlier October Android build does not verify the newly added native timezone plugin.

Local checks are not a claim of market readiness. Physical Android permission/camera testing, real App Check, live Firebase access, configured provider inference/safety, privacy operator details and production deployment remain dependent on real configuration and release validation. Build caches, generated logs and IDE templates may be removed for a clean source directory; build artifacts can be regenerated using the README commands.

3 November 2026 Firebase/Render update: configured the supplied Android and Web registrations for broget-health-ai in ignored client configuration. A read-only Identity Toolkit check matched project number 311190934614 and confirmed localhost plus the two default Firebase Hosting domains are authorized. Added a standalone production server, Render blueprint/environment template, configuration/preflight scripts, separate Android/Web API keys, verification-token refresh and reset/registration regression tests. Local credentials were preserved in ignored backend/.env.local; live structured AI chat and food-schema diagnostics passed after the migration.

Flutter analysis was clean and all 21 Flutter tests passed. All 17 backend tests passed, including actual standalone HTTP startup, health response and unauthenticated-route rejection with a generated test-only credential. Native Android Firebase integration compiled successfully to a diagnostic debug APK; its runtime configuration still lacks the live API URL and App Check site key, so it is not a ready distribution build. PowerShell logged native compiler warnings as error records, but the build log confirms Gradle exit 0 and the built APK. No live account was created, no password-reset email delivery was tested, and no Render/Firebase cloud deployment was performed. Live activation requires Render credentials/URL, App Check registration and the user-controlled email/device acceptance checks in [the setup guide](FIREBASE_AND_RENDER.md).

Implementation references: [Flutter App Check](https://firebase.google.com/docs/app-check/flutter/default-providers), [Firestore field protection](https://firebase.google.com/docs/firestore/security/rules-fields), [structured AI responses](https://ai.google.dev/gemini-api/docs/structured-output), [USDA API guide](https://fdc.nal.usda.gov/api-guide/), and [original Mifflin–St Jeor research](https://pubmed.ncbi.nlm.nih.gov/2305711/).
