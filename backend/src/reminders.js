import { db, FieldValue, ApiError } from './firebase.js';
import { localDateKey, localHour } from './calendar.js';

import { reminderPreferencesSchema, defaultReminders, reminderCandidates } from './reminder_policy.js';
export { reminderPreferencesSchema, defaultReminders, reminderCandidates, isQuiet } from './reminder_policy.js';

// Scheduler-ready: a future authenticated worker can invoke this for an opted-in
// UID. It creates a private outbox/inbox record; it DOES NOT send FCM messages.
export async function generateRemindersForUser(uid, now = new Date()) {
  const root = db.doc(`users/${uid}`);
  const [user, settings, preferences, state] = await Promise.all([
    root.get(), root.collection('settings').doc('preferences').get(),
    root.collection('reminderPreferences').doc('current').get(), root.collection('reportState').doc('index').get(),
  ]);
  if (!state.data()?.complete) return { created: 0, reason: 'reports-indexing', pushDelivery: 'not-connected' };
  const zone = state.data().timeZone, today = localDateKey(now, zone);
  const summary = (await root.collection('dailySummaries').doc(today).get()).data();
  const candidates = reminderCandidates({ enabled: settings.data()?.notifications === true,
    preferences: preferences.data() ? reminderPreferencesSchema.parse(preferences.data()) : defaultReminders,
    today, hour: localHour(now, zone), summary, health: user.data()?.health });
  let created = 0;
  for (const candidate of candidates) {
    const inserted = await db.runTransaction(async tx => {
    const target = root.collection('notifications').doc(candidate.id);
    const [old, owner, lock, liveSettings, livePreferences, liveSummary] = await tx.getAll(target, root, db.doc(`deletionLocks/${uid}`), root.collection('settings').doc('preferences'), root.collection('reminderPreferences').doc('current'), root.collection('dailySummaries').doc(today));
    if (!owner.exists || owner.data().deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    if (old.exists) return false;
    const stillEligible = reminderCandidates({ enabled: liveSettings.data()?.notifications === true,
      preferences: livePreferences.data() ? reminderPreferencesSchema.parse(livePreferences.data()) : defaultReminders,
      today, hour: localHour(now, zone), summary: liveSummary.data(), health: owner.data()?.health });
    if (!stillEligible.some(row => row.id === candidate.id)) return false;
    tx.set(target, { ...candidate, userId: uid, date: today, timeZone: zone, status: 'unread',
      pushStatus: 'not-connected', createdAt: FieldValue.serverTimestamp() });
    tx.set(root.collection('engagementEvents').doc(`reminder_${candidate.id}`), { userId: uid,
      type: 'reminder_created', subjectId: candidate.id, date: today, createdAt: FieldValue.serverTimestamp() });
    return true;
    });
    if (inserted) created++;
  }
  return { created, pushDelivery: 'not-connected' };
}
