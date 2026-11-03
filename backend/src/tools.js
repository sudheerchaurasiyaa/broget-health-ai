import { z } from 'zod';
import { db, Timestamp, ApiError } from './firebase.js';
import { dateRangeSchema, mealSchema, totalMeals } from './contracts.js';
import { searchFood } from './nutrition.js';
import { localDateKey, addDays, reportRangeSchema } from './calendar.js';
import { readReport } from './report_store.js';
import { boundedMemory, compactReport, recentNutrition } from './assistant_context.js';

export function calculateTarget(p) {
  if (!p || p.age < 18 || p.age > 100 || p.heightCm < 100 || p.heightCm > 250 || p.weightKg < 30 || p.weightKg > 350 || p.specialCare || !['female', 'male'].includes(p.gender)) return null;
  const factor = { sedentary: 1.2, light: 1.375, moderate: 1.55, active: 1.725 }[p.activity];
  if (!factor) return null;
  const bmr = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age + (p.gender === 'male' ? 5 : -161);
  const energy = bmr * factor;
  const calories = Math.round(Math.max(p.gender === 'male' ? 1500 : 1200, energy + ({ lose: -300, gain: 300 }[p.goal] ?? 0)));
  const protein = Math.round(p.weightKg * (p.goal === 'gain' ? 1.6 : 1.2));
  const fat = Math.round(calories * .3 / 9);
  return { bmr: Math.round(bmr), energy: Math.round(energy), calories, protein, fat, carbs: Math.max(0, Math.round((calories - protein * 4 - fat * 9) / 4)), fiber: 30 };
}
export async function mealsForRange(uid, range, limit = 600) {
  dateRangeSchema.parse(range);
  const snap = await db.collection(`users/${uid}/meals`)
    .where('eatenAt', '>=', Timestamp.fromDate(new Date(range.start)))
    .where('eatenAt', '<', Timestamp.fromDate(new Date(range.end)))
    .orderBy('eatenAt').limit(limit + 1).get();
  if (snap.size > limit) throw new ApiError(422, 'range-too-large');
  return snap.docs.map(d => ({ id: d.id, ...d.data(), eatenAt: d.data().eatenAt.toDate().toISOString() }));
}
export async function authorizedContext(uid, range) {
  const [profile, state, memory] = await Promise.all([db.doc(`users/${uid}`).get(), db.doc(`users/${uid}/reportState/index`).get(), boundedMemory(uid)]);
  const user = profile.data();
  const zone = state.data()?.timeZone ?? 'UTC';
  const today = localDateKey(new Date(), zone);
  const dayReport = await readReport(uid, today, addDays(today, 1));
  const latest = await db.collection(`users/${uid}/meals`).where('localDate', '==', today).limit(12).get();
  const meals = latest.docs.map(d => ({ id: d.id, ...d.data(), eatenAt: d.data().eatenAt.toDate().toISOString() }));
  const context = { localDay: range, target: calculateTarget(user?.health), dailyNutrition: dayReport.totals,
    reportingDate: today, reportingTimeZone: zone,
    recentWeek: state.data()?.complete ? await recentNutrition(uid, today) : null,
    memory,
    meals: meals.slice(-12).map(m => ({ id: m.id, mealType: m.mealType, eatenAt: m.eatenAt, foods: m.foods.map(f => ({ name: f.food.name, grams: f.grams, source: f.source })) })),
    preferences: user?.health ? { goal: user.health.goal, activity: user.health.activity, diet: user.health.diet, allergies: user.health.allergies, restrictions: user.health.restrictions, specialCare: user.health.specialCare } : null };
  while (JSON.stringify(context).length > 19700 && context.memory.recentMessages.length) context.memory.recentMessages.shift();
  while (JSON.stringify(context).length > 19700 && context.meals.length) context.meals.pop();
  context.contextPolicy = 'Bounded to 20,000 characters; recent messages and selected meal details may be omitted. Use authorized date tools for other records. Missing logs are not zero intake.';
  return context;
}
export async function executeTool(uid, tool, localRange) {
  switch (tool.name) {
    case 'getUserProfile': {
      z.object({}).strict().parse(tool.arguments);
      const h = (await db.doc(`users/${uid}`).get()).data()?.health;
      return { profile: h ? { diet: h.diet, allergies: h.allergies, restrictions: h.restrictions, goal: h.goal, specialCare: h.specialCare } : null };
    }
    case 'getDailyTarget':
    case 'getDailyNutrition': {
      z.object({}).strict().parse(tool.arguments);
      const context = await authorizedContext(uid, localRange);
      return tool.name === 'getDailyTarget' ? context.target : context.dailyNutrition;
    }
    case 'getNutritionForDate':
    case 'getMealHistory':
      {
        if ('startDate' in tool.arguments) {
          const dates = reportRangeSchema.parse(tool.arguments);
          if ((Date.parse(dates.endDate) - Date.parse(dates.startDate)) / 86400000 > 32) throw new ApiError(400, 'invalid-input');
          const report = await readReport(uid, dates.startDate, dates.endDate);
          if (tool.name === 'getNutritionForDate') return compactReport(report);
          const page = await db.collection(`users/${uid}/meals`).where('localDate', '>=', dates.startDate)
            .where('localDate', '<', dates.endDate).orderBy('localDate').limit(21).get();
          return { range: dates, totals: report.totals, truncated: page.size > 20,
            meals: page.docs.slice(0, 20).map(d => ({ id: d.id, mealType: d.data().mealType, localDate: d.data().localDate,
              foods: d.data().foods.slice(0, 6).map(f => ({ name: f.food.name.slice(0, 80), grams: f.grams })) })) };
        }
        const range = dateRangeSchema.parse(tool.arguments);
        const meals = await mealsForRange(uid, range);
        return { range, totals: totalMeals(meals), truncated: meals.length > 20,
          meals: meals.slice(-20).map(m => ({ id: m.id, mealType: m.mealType, eatenAt: m.eatenAt,
            foods: m.foods.slice(0, 6).map(f => ({ name: f.food.name.slice(0, 80), grams: f.grams })) })) };
      }
    case 'getConversationHistory': {
      const range = dateRangeSchema.parse(tool.arguments);
      const page = await db.collection(`users/${uid}/chat`)
        .where('createdAt', '>=', Timestamp.fromDate(new Date(range.start)))
        .where('createdAt', '<', Timestamp.fromDate(new Date(range.end)))
        .orderBy('createdAt', 'desc').limit(21).get();
      return { range, truncated: page.size > 20, messages: page.docs.slice(0, 20).reverse()
        .filter(d => d.data().verified && !d.data().requestPending)
        .map(d => ({ role: d.data().role, text: d.data().text.slice(0, 800), date: d.data().createdAt.toDate().toISOString() })) };
    }
    case 'getWeeklySummary':
    case 'getMonthlySummary':
    case 'getYearlySummary': {
      let range;
      if ('startDate' in tool.arguments) range = reportRangeSchema.parse(tool.arguments);
      else {
        const iso = dateRangeSchema.parse(tool.arguments);
        const state = (await db.doc(`users/${uid}/reportState/index`).get()).data();
        range = { startDate: localDateKey(iso.start, state?.timeZone ?? 'UTC'), endDate: localDateKey(iso.end, state?.timeZone ?? 'UTC') };
      }
      return compactReport(await readReport(uid, range.startDate, range.endDate));
    }
    case 'searchFood': {
      const { query } = z.object({ query: z.string().trim().min(2).max(100) }).strict().parse(tool.arguments);
      return { foods: await searchFood(query) };
    }
    case 'addMeal':
    case 'updateMeal': {
      const { meal } = z.object({ meal: mealSchema }).strict().parse(tool.arguments);
      if (tool.name === 'updateMeal' && !(await db.doc(`users/${uid}/meals/${meal.id}`).get()).exists) throw new ApiError(404, 'meal-not-found');
      return { requiresUserConfirmation: true, action: tool.name, meal };
    }
    case 'deleteMeal': {
      const { id } = z.object({ id: z.string().uuid() }).strict().parse(tool.arguments);
      if (!(await db.doc(`users/${uid}/meals/${id}`).get()).exists) throw new ApiError(404, 'meal-not-found');
      return { requiresUserConfirmation: true, action: 'deleteMeal', id };
    }
    default: throw new ApiError(400, 'invalid-tool');
  }
}
