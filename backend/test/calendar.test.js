import test from 'node:test';
import assert from 'node:assert/strict';
import { localDateKey, localHour, contribution, emptyDay, applyDelta, summarizeDays, reportRangeSchema } from '../src/calendar.js';
import { reminderCandidates, defaultReminders, isQuiet } from '../src/reminder_policy.js';

const meal = (when, grams = 100) => ({ eatenAt: when, mealType: 'lunch', foods: [{ grams, food: { per100g: { calories: 130, protein: 2, carbs: 28, fat: .3, fiber: null } } }] });
test('local dates follow IANA zones across midnight and daylight-saving changes', () => {
  assert.equal(localDateKey('2025-12-31T20:00:00Z', 'Asia/Calcutta'), '2026-01-01');
  assert.equal(localDateKey('2026-03-09T03:30:00Z', 'America/New_York'), '2026-03-08');
  assert.equal(localHour('2026-03-08T06:30:00Z', 'America/New_York'), 1);
  assert.equal(localHour('2026-03-08T07:30:00Z', 'America/New_York'), 3);
});
test('replacing indexed contributions is idempotent and handles edits and deletion', () => {
  const first = contribution(meal('2026-01-01T12:00:00Z'), 'UTC');
  const updated = contribution(meal('2026-01-01T12:00:00Z', 150), 'UTC');
  let summary = applyDelta(emptyDay(first.date), null, first);
  summary = applyDelta(summary, first, first);
  assert.equal(summary.mealCount, 1); assert.equal(summary.calories, 130);
  summary = applyDelta(summary, first, updated);
  assert.equal(summary.mealCount, 1); assert.equal(summary.calories, 195);
  assert.equal(summary.unknownFiberCount, 1);
  summary = applyDelta(summary, updated, null);
  assert.equal(summary.mealCount, 0); assert.equal(summary.calories, 0); assert.equal(summary.unknownFiberCount, 0);
});
test('calendar-year reports include leap day, gaps and logged-day averages', () => {
  const row = contribution(meal('2024-02-29T12:00:00Z'), 'UTC');
  const report = summarizeDays('2024-01-01', '2025-01-01', [row]);
  assert.equal(report.calendarDays, 366); assert.equal(report.loggedDays, 1);
  assert.equal(report.totals.calories, 130); assert.equal(report.averages.calories, 130);
  assert.equal(report.averages.fiber, null);
  assert.equal(report.days.find(d => d.date === '2024-02-28').mealCount, 0);
  assert.equal(reportRangeSchema.safeParse({ startDate: '2023-01-01', endDate: '2025-01-01' }).success, false);
  assert.equal(reportRangeSchema.safeParse({ startDate: '2026-02-30', endDate: '2026-03-02' }).success, false);
});
test('reminders respect opt-in, quiet hours, recorded meals and care exclusions', () => {
  const context = { enabled: true, preferences: { ...defaultReminders, mealReminders: true, movementReminders: true }, today: '2026-11-02', hour: 20, summary: null, health: { age: 30, specialCare: false } };
  assert.equal(reminderCandidates(context).length, 2);
  assert.equal(reminderCandidates({ ...context, enabled: false }).length, 0);
  assert.equal(reminderCandidates({ ...context, hour: 23 }).length, 0);
  assert.equal(reminderCandidates({ ...context, summary: { mealTypes: { dinner: 1 } } }).length, 1);
  assert.equal(reminderCandidates({ ...context, health: { age: 16 } }).some(r => r.kind === 'movement'), false);
  assert.equal(reminderCandidates({ ...context, health: { age: 30, specialCare: true } }).some(r => r.kind === 'movement'), false);
  assert.ok(isQuiet(2, 22, 8)); assert.ok(!isQuiet(12, 22, 8));
  assert.match(reminderCandidates(context)[0].reason, /does not mean you have not eaten/);
});
