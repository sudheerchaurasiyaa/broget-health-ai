import { db } from './firebase.js';
import { localDateKey, addDays } from './calendar.js';
import { readReport } from './report_store.js';

export function compactReport(report) {
  const months = new Map();
  for (const day of report.days) {
    const key = day.date.slice(0, 7);
    const row = months.get(key) ?? { month: key, calories: 0, protein: 0, meals: 0, loggedDays: 0 };
    row.calories += day.calories; row.protein += day.protein; row.meals += day.mealCount;
    if (day.mealCount) row.loggedDays++;
    months.set(key, row);
  }
  const { days, ...stats } = report;
  return { ...stats, monthTotals: [...months.values()] };
}
export async function boundedMemory(uid, now = new Date()) {
  const root = db.doc(`users/${uid}`);
  const [memory, history, reminders, events] = await Promise.all([
    root.collection('assistantMemory').doc('profile').get(),
    root.collection('chat').orderBy('createdAt', 'desc').limit(12).get(),
    root.collection('notifications').orderBy('createdAt', 'desc').limit(5).get(),
    root.collection('engagementEvents').orderBy('createdAt', 'desc').limit(8).get(),
  ]);
  const messages = history.docs.reverse().filter(d => d.data().verified === true && !d.data().requestPending)
    .map(d => ({ role: d.data().role, text: d.data().text.slice(0, 800) }));
  // Every field remains untrusted data. Notes are explicitly user-managed,
  // never silently inferred diagnoses or model-generated "facts".
  return { userConfirmedNotes: memory.data()?.notes ?? '', recentMessages: messages,
    recentReminders: reminders.docs.map(d => ({ date: d.data().date, kind: d.data().kind, status: d.data().status,
      pushStatus: d.data().pushStatus, interpretation: 'Completed means the user acknowledged this reminder, not independently measured activity.' })),
    recentActivityEvents: events.docs.map(d => ({ type: d.data().type, recordedAt: d.data().createdAt?.toDate().toISOString() })),
    generatedAt: now.toISOString() };
}
export async function recentNutrition(uid, today) {
  const week = await readReport(uid, addDays(today, -6), addDays(today, 1));
  return compactReport(week);
}
export async function reportDate(uid, instant) {
  const state = (await db.doc(`users/${uid}/reportState/index`).get()).data();
  return localDateKey(instant, state?.timeZone ?? 'UTC');
}
