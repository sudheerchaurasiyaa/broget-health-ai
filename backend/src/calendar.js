import { z } from 'zod';

export const timeZoneSchema = z.string().min(1).max(100).refine(value => {
  try { new Intl.DateTimeFormat('en', { timeZone: value }).format(); return true; } catch { return false; }
}, 'Use a valid IANA timezone');
export const calendarDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value => {
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
});
export const reportRangeSchema = z.object({ startDate: calendarDateSchema, endDate: calendarDateSchema }).strict()
  .refine(v => {
    const days = (Date.parse(v.endDate) - Date.parse(v.startDate)) / 86400000;
    return days > 0 && days <= 366;
  }, 'Select at most one calendar year');
export function localDateKey(instant, timeZone) {
  timeZoneSchema.parse(timeZone);
  const parts = new Intl.DateTimeFormat('en-US', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date(instant));
  const get = type => parts.find(p => p.type === type).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}
export function addDays(day, count) {
  calendarDateSchema.parse(day);
  return new Date(Date.parse(`${day}T00:00:00Z`) + count * 86400000).toISOString().slice(0, 10);
}
export function localHour(instant, timeZone) {
  return Number(new Intl.DateTimeFormat('en-US', { timeZone, hour: '2-digit', hourCycle: 'h23' }).format(new Date(instant)));
}
export function emptyDay(day) {
  return { date: day, mealCount: 0, calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, unknownFiberCount: 0,
    mealTypes: { breakfast: 0, lunch: 0, dinner: 0, snack: 0 } };
}
export function contribution(meal, zone) {
  const when = meal.eatenAt?.toDate ? meal.eatenAt.toDate() : new Date(meal.eatenAt);
  const out = emptyDay(localDateKey(when, zone));
  out.mealCount = 1;
  out.mealTypes[meal.mealType] = 1;
  for (const item of meal.foods) for (const key of ['calories', 'protein', 'carbs', 'fat', 'fiber']) {
    if (item.food.per100g[key] == null) { if (key === 'fiber') out.unknownFiberCount++; }
    else out[key] += item.food.per100g[key] * item.grams / 100;
  }
  return out;
}
export function applyDelta(day, oldValue, newValue) {
  const out = { ...day, mealTypes: { ...day.mealTypes } };
  for (const [value, sign] of [[oldValue, -1], [newValue, 1]]) if (value) {
    for (const key of ['mealCount', 'calories', 'protein', 'carbs', 'fat', 'fiber', 'unknownFiberCount']) out[key] += sign * value[key];
    for (const key of Object.keys(out.mealTypes)) out.mealTypes[key] += sign * value.mealTypes[key];
  }
  for (const key of ['calories', 'protein', 'carbs', 'fat', 'fiber']) out[key] = Math.max(0, Math.round(out[key] * 1e8) / 1e8);
  if (out.mealCount < 0 || out.unknownFiberCount < 0 || Object.values(out.mealTypes).some(v => v < 0)) throw new Error('Invalid summary state');
  return out;
}
export function summarizeDays(startDate, endDate, rows) {
  reportRangeSchema.parse({ startDate, endDate });
  const byDate = new Map(rows.map(row => [row.date, row]));
  const days = [];
  for (let date = startDate; date < endDate; date = addDays(date, 1)) days.push(byDate.get(date) ?? emptyDay(date));
  const totals = emptyDay(startDate);
  for (const day of days) {
    for (const key of ['mealCount', 'calories', 'protein', 'carbs', 'fat', 'fiber', 'unknownFiberCount']) totals[key] += day[key];
    for (const key of Object.keys(totals.mealTypes)) totals.mealTypes[key] += day.mealTypes[key];
  }
  const loggedDays = days.filter(d => d.mealCount > 0).length;
  const averages = Object.fromEntries(['calories', 'protein', 'carbs', 'fat', 'fiber'].map(k => [k, k === 'fiber' && totals.unknownFiberCount > 0 ? null : loggedDays ? totals[k] / loggedDays : 0]));
  return { startDate, endDate, days, totals, loggedDays, calendarDays: days.length, averages };
}
