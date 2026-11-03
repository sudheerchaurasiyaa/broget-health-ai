# Personal context, calendar reporting and reminder records

Each account's source records live in Firestore, not in model RAM. In the local emulator, records are temporary unless exported. Use `scripts/dev-emulators.ps1` to import prior local data and export it on a normal Ctrl+C shutdown. Cloud Firestore is the durable deployment store. No user data or emulator exports should be committed to Git.

## Private organization

```text
users/{verifiedUid}
  meals/{uuid}                     confirmed foods, grams, UTC instant, localDate
  dailySummaries/{YYYY-MM-DD}       server-maintained totals, meal counts, year/month
  summaryContributions/{mealId}    each meal's indexed contribution
  reportState/index                fixed IANA reporting zone, migration progress
  chat/{requestId[_reply]}         server-authored message role and timestamp
  chatTurns/{requestId}            deduplication and completed response cache
  assistantMemory/profile         user-confirmed notes, at most 1,000 characters
  reportNarratives/{uuid}          generated explanation with its numerical snapshot
  reminderPreferences/current     opted-in kinds, hours and quiet hours
  notifications/{date_kind}       private inbox and future push-outbox record
  engagementEvents/{id}           meal changes, exchanges and reminder responses
```

The UID comes only from verified authentication. Rules deny direct client writes to totals, chat, reminders and event history. Client-supplied assistant messages can no longer impersonate assistant output. Older messages lacking server verification remain visible in the journal but are excluded from assistant context.

## Retrieval policy

An assistant request receives:

- The current estimated target and relevant dietary preferences from the user's profile.
- Explicitly user-confirmed notes, never silently inferred permanent diagnoses or facts.
- At most 12 recent server-verified messages, each capped at 800 characters.
- Current-day deterministic nutrition totals and selected food details, plus a compact recent-week summary.
- At most five recent reminders and eight recent activity events. A user clicking done is a self-report, not measured walking or exercise.

Base context is capped at 20,000 characters by dropping older message/details first. Historical meal/conversation tools retrieve only authorized date ranges, with bounded results and a truncation flag. Raw ranges are limited to 32 days; aggregate tools support one calendar year. Weekly/monthly/yearly tools use daily summaries and send compact statistics, including at most 12 month buckets, instead of every historical meal. All stored text remains untrusted input under the assistant's fixed instructions. This is structured retrieval, not an assertion that the model permanently knows everything about a person.

Chat writes are backend-owned. A stable request UUID caches successful responses and prevents duplicate messages on retries. Failed requests are retryable; pending or failed user entries are not used as completed conversation context. Clearing chat deletes messages and turn caches. Confirmed notes are edited separately. Account deletion removes all private subcollections, including notes, summaries, reminders and events.

## Daily through yearly reports

Meal mutation and aggregate correction happen in the same transaction. Updating quantities replaces the old contribution; moving dates subtracts from the old day and adds to the new day; deleting a meal removes its contribution. Identical saves do not add another meal or audit event.

The first journal timezone is stored as an IANA zone (including DST rules). It remains fixed for historical consistency when a user travels. Reports display that zone. UTC timestamps remain the source for raw timeline queries, while sortable local date keys support calendar queries. The fixed zone is not silently changed; changing a historical reporting zone would require a deliberate reindex operation.

Legacy meals are indexed in pages of 50, with persisted progress and idempotent per-meal contributions. A client processes up to 20 pages at a time and asks for a retry if more remain. Reports wait for indexing completion rather than returning incomplete totals. New writes are indexed immediately. No entire history is loaded into an AI request during migration.

Daily, weekly and monthly reports show daily bars. Yearly reports read at most 366 daily documents and show 12 monthly averages with drill-down to a month. Missing days remain distinct from zero intake. Averages use logged days, and partially logged days can understate intake. Historical comparisons use the current estimated target and say so. AI explains deterministic totals; it does not calculate the totals.

## Current reminder behavior

Enable personalized reminders and choose meal/movement kinds in Settings. The application evaluates eligibility after opening a completed profile and when the reminder inbox is opened/refreshed. It uses saved timezone, chosen times, quiet hours and recorded dinner count. It creates at most one meal reminder and one movement reminder per local day; transaction checks revalidate current consent and meal state.

No dinner record means only that dinner is unrecorded. Movement reminders are optional routine prompts, never advice to compensate for food, and never assert that walking was measured. Movement prompts are suppressed for minors and special-care profiles.

Records include the reason, date/timezone, unread/opened/dismissed/completed state and an explicit `pushStatus=not-connected`. Each response is recorded as an activity event. Generated report explanations are also recorded with the numerical snapshot used to produce them.

## Later FCM integration

FCM sending is deliberately not active. `generateRemindersForUser(uid, now)` is the scheduler-ready eligibility/outbox function. A future worker must:

1. Register user-consented device tokens, handle refresh/sign-out/revocation and remove invalid tokens.
2. Run from a trusted scheduler, recheck current consent/quiet hours and claim an unsent outbox record transactionally.
3. Send a privacy-conscious generic notification plus an inbox ID/deep link, without sensitive health details on a lock screen by default.
4. Record accepted-send IDs and errors, bounded retries, expiry and token cleanup. An FCM accepted-send result must not be called delivered or read.
5. Record actual client opens/acknowledgments separately. Handle duplicate worker runs and ambiguous sends; do not promise exactly-once delivery.

Choose a hosting-appropriate scheduler after deployment. Merely installing Firebase Messaging does not run personalized schedules when the app is closed. Existing per-user records and consent logic can be reused without sending the entire user history to a model.

Design references: [Firestore write-time aggregation](https://firebase.google.com/docs/firestore/solutions/aggregation), [atomic transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [FCM message types](https://firebase.google.com/docs/cloud-messaging/customize-messages/set-message-type), and [emulator data export/import](https://firebase.google.com/docs/emulator-suite/install_and_configure).
