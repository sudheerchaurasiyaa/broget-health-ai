# Health Broget architecture

One Flutter application targets Android and responsive Web. Riverpod owns asynchronous state; GoRouter owns guarded, deep-linkable navigation. Widgets call repositories, never Firestore queries. Firebase Auth persists identity, Firestore stores private profiles/meals/settings/chat, and App Check attests production requests. Photo storage is coming soon: the application has no Storage SDK or bucket dependency. Food photos are resized and sent directly to the authenticated analysis backend without being retained.

`HealthBrogetService` is the provider-independent client contract. Its HTTP implementation calls the same Node backend in every environment. Locally, Express runs alongside the Firebase emulators without deployed Cloud Functions or paid cloud infrastructure. Production exports the identical Express application as a Firebase HTTPS function. Provider credentials never enter Dart, APKs, or web bundles.

The backend verifies Auth and App Check, derives the UID exclusively from verified credentials, enforces transaction-based quotas, validates strict request/output schemas, and supplies bounded authorized nutrition context. Photo scanning prefills approximate per-100g nutrition and portions, with private server-owned snapshots and explicit AI provenance. Users review and can edit them before saving a meal. USDA FoodData Central and an administrator-managed Firestore food catalog separately provide attributed nutrition matches. Only confirmed meals enter totals; deterministic services calculate targets, meal totals and reports.

## Source tree

```text
lib/
  core/config/        build-time public configuration and environment guards
  core/theme/         shared responsive design system
  core/errors/        safe actionable error translation
  data/models/        validated domain types and deterministic calculations
  data/repositories/  auth, profiles, meals, settings and chat persistence
  services/ai/        provider-independent API client
  services/images/    local image selection, validation and resizing; no storage
  routing/           session/profile guards and public/private URLs
  features/          public, auth, profile, dashboard, scanner, meals,
                     reports, assistant, settings, notification inbox
  widgets/           consistent asynchronous and responsive UI
backend/
  src/               Express app, contracts, provider, controlled tools,
                     authorization, quotas, nutrition and deletion
  test/              request, safety, schema, nutrition and rule tests
config/              public Dart define examples; no secrets
scripts/             checked builds, emulator and deployment helpers
test/                domain, state, routing and responsive widget tests
android/             native application and release signing setup
web/                 PWA manifest, public metadata and static crawler pages
```

## Data boundaries

Private collections live under `users/{uid}`. Owner access requires a live account document without deletion lock. Rules deny arbitrary subcollections, extra fields, role writes, and forged server timestamps. Meal writes go through the backend; direct client mutations are denied. The server resolves trusted nutrition snapshots, validates every food and commits stable IDs with immutable creation metadata. Meals use UTC timestamps, explicit nutrition and recognition provenance, bounded quantities and per-100g nutrient snapshots. Reports derive from bounded date-range queries using local-day boundaries; missing days remain visible and are excluded from logged-day averages.

API tools accept a fixed enum, strict arguments and bounded ranges. Read tools never take a UID. Write tools return validated proposals requiring explicit user confirmation in the meal editor. The model cannot execute database operations. Account deletion first locks the account, removes every private subcollection, clears personal root fields, revokes tokens, removes Auth and finally deletes the locked root; retries resume incomplete deletion with recently authenticated credentials. No deletion step requires a storage bucket.

## Configuration and rollout

Public Firebase identifiers are build configuration, not credentials. Server-only secrets live in ignored `backend/.env` locally and Secret Manager in production. A checked production build rejects local endpoints, emulator configuration, missing attestation and development secret defines. Release Android signing is mandatory. Hosting rewrites support browser refresh/deep links; authenticated routes carry noindex metadata. No deployment, live service connection, or store availability is implied by generated source.

## Personal context and date organization

Server-owned daily summaries use sortable YYYY-MM-DD document IDs plus year/month fields in a fixed IANA reporting timezone. Meal snapshots and aggregate contributions change in one transaction. Legacy records migrate with bounded resumable pages. Yearly reports read daily summaries rather than a full meal history and chart at most 12 month buckets. Chat is backend-authored with stable request UUIDs; only a bounded recent window, relevant date summaries, user-confirmed notes and recent reminder/event states are retrieved for AI context. Full design and FCM rollout boundaries are in [CONTEXT_AND_REMINDERS.md](docs/CONTEXT_AND_REMINDERS.md).
