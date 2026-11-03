import { z } from 'zod';

export const reminderPreferencesSchema = z.object({
  mealReminders: z.boolean(), movementReminders: z.boolean(),
  mealHour: z.number().int().min(0).max(23), movementHour: z.number().int().min(0).max(23),
  quietStart: z.number().int().min(0).max(23), quietEnd: z.number().int().min(0).max(23),
}).strict();
export const defaultReminders = { mealReminders: false, movementReminders: false, mealHour: 20, movementHour: 17, quietStart: 22, quietEnd: 8 };
export function isQuiet(hour, start, end) {
  return start === end ? false : start < end ? hour >= start && hour < end : hour >= start || hour < end;
}
export function reminderCandidates({ enabled, preferences, today, hour, summary, health }) {
  if (!enabled || isQuiet(hour, preferences.quietStart, preferences.quietEnd)) return [];
  const result = [];
  if (preferences.mealReminders && hour >= preferences.mealHour && !(summary?.mealTypes?.dinner > 0)) result.push({
    id: `${today}_meal`, kind: 'meal_log', title: 'A moment for your food journal',
    body: 'No dinner entry is recorded for today. If you have eaten and would like to track it, add your meal when convenient.',
    reason: 'No recorded dinner at your chosen reminder time. This does not mean you have not eaten.',
    route: '/app/meals',
  });
  if (preferences.movementReminders && !health?.specialCare && health?.age >= 18 && hour >= preferences.movementHour) result.push({
    id: `${today}_movement`, kind: 'movement', title: 'Your optional movement break',
    body: 'If it is comfortable and safe for you, consider a gentle movement break. Choose what suits your day.',
    reason: 'A user-selected routine reminder. Activity is not measured and this is not a response to calorie intake.',
    route: '/app',
  });
  return result;
}

