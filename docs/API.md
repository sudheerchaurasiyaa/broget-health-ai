# Backend contract

All routes except `GET /health` require `Authorization: Bearer <Firebase ID token>`. Production also requires `X-Firebase-AppCheck`. Identity is derived from the verified token; request bodies must not contain user IDs. Email verification is required for scans, chat, summaries and food search in production. Errors return only a stable `{ "code": "..." }` and an opaque request-ID header. Never display upstream errors.

| Route | Behavior |
|---|---|
| GET /foods?q= | 2–100 character search; USDA plus curated regional catalog, up to 20 matches |
| POST /analyze | Base64 JPEG/PNG/WebP, reference boolean and referenceDescription; structured food/portion recognition and approximate per100g nutrition; each result includes a private server-owned nutrition snapshot for meal review |
| PUT /meals/:uuid | Strict confirmed meal; at most 12 foods and 3,000 g each; resolves trusted nutrition snapshots server-side; idempotent transaction |
| DELETE /meals/:uuid | Delete only caller's meal; no bucket dependency |
| POST /chat | Message up to 2,000 characters, stable requestId UUID, IANA timeZone and UTC start/end of caller's local day; server-owned conversation persistence |
| POST /summary | startDate/endDate calendar range, maximum 366 days; explain deterministic daily totals and archive the explanation |
| POST /reports/prepare | IANA timeZone; resume a page of 50 legacy meals and return complete/processed/reporting timezone |
| GET /reports?startDate=&endDate= | Calendar report from at most 366 daily summary documents, including missing days |
| GET /assistant-memory | User-confirmed notes for the caller only |
| PUT /assistant-memory | Replace caller's confirmed notes, maximum 1,000 characters |
| GET/PUT /reminders/preferences | Opted-in meal/movement kinds, local hours and quiet hours |
| POST /notifications/check | Evaluate caller's reminder eligibility; no FCM sending |
| GET /notifications?cursor= | Paginated private inbox, 20 records per page |
| POST /notifications/:id/action | Record opened, dismissed or completed and append an event |
| DELETE /chat | Remove caller's conversations and turn caches; confirmed notes remain separately editable |
| DELETE /account | Recent authentication (5 minutes), exact confirmation DELETE; lock account, remove private data, revoke tokens and delete Auth |
| PUT /admin/foods/:id | Custom claim admin=true; validated food and exact normalized search terms |
| GET /admin/metrics | Custom claim admin=true; user count only |

Food snapshots contain `id`, `name`, `per100g` (calories, protein, carbs, fat, nullable fiber) and `attribution`. Meal foods additionally contain grams, recognition source and nullable confidence. The server stores a separate nutritionSource: nutrition_database, ai_estimate or user_entered. Scan foods have IDs `ai:<hash>:<index>` and immutable structured snapshots under the caller's private `scanFoods` collection. Meal writes resolve them for that authenticated user; client-supplied nutrient changes cannot replace these server values. The editor saves explicitly edited nutrients as user-entered values with their source description. Private structured scan snapshots remain until account deletion so old meals can be edited after analysis-cache expiry. Numerical totals always use stored quantities and nutrient snapshots. An empty foods array means no food was identified and cannot be saved as a meal.

Photo storage is coming soon. imagePath must be null. Photo-retention attempts return photo-storage-unavailable. Scan bytes are processed in memory and never written to Firestore or a bucket; only the validated structured analysis may be cached.

Limits: 600 authenticated requests/hour, 120 food searches/hour, 20 scans/hour with 8-second throttling, 60 chats/hour with 3-second throttling, 12 summaries/hour. Limits use transactional private Firestore documents. Configure TTL policies for cleanup, and set cloud budgets/alerts independently. Instance limits bound concurrency but are not a hard spending cap.

Controlled assistant tools use fixed names and validated arguments. Tools never accept an account ID. Base context is bounded to 20,000 characters, with at most 12 recent verified messages, selected current-day meals, confirmed notes, a recent-week summary and bounded reminder/event history. Historical meal/conversation ranges are at most 32 days; calendar aggregate tools support up to 366 days and send statistics plus at most 12 monthly buckets. Write tools return proposals only. Account email, credentials and full health measurements are not sent in context. See [context and reminder design](CONTEXT_AND_REMINDERS.md).
