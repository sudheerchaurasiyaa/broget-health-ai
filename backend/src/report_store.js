import { randomUUID } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import { FieldPath } from 'firebase-admin/firestore';
import { db, ApiError, FieldValue } from './firebase.js';
import { contribution, emptyDay, applyDelta, summarizeDays, reportRangeSchema, timeZoneSchema } from './calendar.js';

// Meal and its old/new daily totals change atomically, including date moves and
// deletion. A contribution document makes migration and request retries idempotent.
export async function mutateMeal(uid, id, input, requestedZone = 'UTC') {
  timeZoneSchema.parse(requestedZone);
  const user = db.doc(`users/${uid}`), meal = user.collection('meals').doc(id);
  const index = user.collection('summaryContributions').doc(id), state = user.collection('reportState').doc('index');
  await db.runTransaction(async tx => {
    const [previous, previousIndex, stateSnap, userSnap, lock] = await tx.getAll(meal, index, state, user, db.doc(`deletionLocks/${uid}`));
    if (!userSnap.exists || userSnap.data().deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    const zone = stateSnap.data()?.timeZone ?? requestedZone;
    const current = input === undefined ? previous.data() : input;
    if (input !== undefined && previousIndex.exists && current && previous.exists) {
      const old = previous.data();
      if (old.mealType === current.mealType && old.eatenAt.toMillis() === current.eatenAt.toMillis()
        && old.imagePath === current.imagePath && isDeepStrictEqual(old.foods, current.foods)) return;
    }
    if (input === null && !previous.exists && !previousIndex.exists) return;
    const oldValue = previousIndex.data()?.value ?? null;
    const newValue = current ? contribution(current, zone) : null;
    const affected = [...new Set([oldValue?.date, newValue?.date].filter(Boolean))];
    const refs = affected.map(day => user.collection('dailySummaries').doc(day));
    const summaries = refs.length ? await tx.getAll(...refs) : [];
    // The account can be cleared while a report migration is running. Lock reads
    // above make that race retry and fail before any personal record is restored.
    affected.forEach((day, i) => {
      const result = applyDelta(summaries[i].data() ?? emptyDay(day), oldValue?.date === day ? oldValue : null, newValue?.date === day ? newValue : null);
      if (result.mealCount === 0) tx.delete(refs[i]);
      else tx.set(refs[i], { ...result, year: Number(day.slice(0, 4)), month: Number(day.slice(5, 7)), dayOfMonth: Number(day.slice(8, 10)), userId: uid, timeZone: zone, updatedAt: FieldValue.serverTimestamp() });
    });
    if (!stateSnap.exists) tx.set(state, { timeZone: zone, complete: false, cursor: null, version: 1 });
    if (newValue) tx.set(index, { value: newValue, updatedAt: FieldValue.serverTimestamp() });
    else tx.delete(index);
    if (input !== undefined) {
      if (current) tx.set(meal, { ...current, userId: uid, localDate: newValue.date, reportingTimeZone: zone,
        createdAt: previous.exists ? previous.data().createdAt : FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      else tx.delete(meal);
      tx.set(user.collection('engagementEvents').doc(randomUUID()), { userId: uid,
        type: !current ? 'meal_deleted' : previous.exists ? 'meal_updated' : 'meal_logged',
        subjectId: id, date: newValue?.date ?? oldValue?.date ?? null, createdAt: FieldValue.serverTimestamp() });
    } else if (previous.exists && newValue) {
      tx.update(meal, { localDate: newValue.date, reportingTimeZone: zone });
    }
  });
}

export async function prepareReports(uid, requestedZone) {
  timeZoneSchema.parse(requestedZone);
  const user = db.doc(`users/${uid}`), state = user.collection('reportState').doc('index');
  const status = (await state.get()).data();
  const zone = status?.timeZone ?? requestedZone;
  if (status?.complete) return { complete: true, timeZone: zone };
  let query = user.collection('meals').orderBy(FieldPath.documentId()).limit(50);
  if (status?.cursor) query = query.startAfter(status.cursor);
  const page = await query.get();
  for (const meal of page.docs) await mutateMeal(uid, meal.id, undefined, zone);
  // Progress is advisory. Repeating an interrupted page is safe because every
  // meal's indexed contribution is replaced, never double-counted.
  await db.runTransaction(async tx => {
    const [live, owner, lock] = await tx.getAll(state, user, db.doc(`deletionLocks/${uid}`));
    if (!owner.exists || owner.data().deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    const cursor = page.docs.at(-1)?.id ?? status?.cursor ?? null;
    tx.set(state, { timeZone: live.data()?.timeZone ?? zone, complete: live.data()?.complete === true || page.size < 50,
      cursor: cursor && (!live.data()?.cursor || cursor > live.data().cursor) ? cursor : live.data()?.cursor ?? cursor, version: 1 }, { merge: true });
  });
  return { complete: page.size < 50, processed: page.size, timeZone: zone };
}

export async function readReport(uid, startDate, endDate) {
  reportRangeSchema.parse({ startDate, endDate });
  const state = (await db.doc(`users/${uid}/reportState/index`).get()).data();
  if (!state?.complete) throw new ApiError(409, 'reports-indexing');
  const rows = await db.collection(`users/${uid}/dailySummaries`).where('date', '>=', startDate).where('date', '<', endDate).orderBy('date').limit(367).get();
  return { ...summarizeDays(startDate, endDate, rows.docs.map(d => d.data())), timeZone: state.timeZone };
}
