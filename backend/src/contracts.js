import { z } from 'zod';
import { timeZoneSchema } from './calendar.js';

export const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
export const nutrients = z.object({
  calories: z.number().finite().min(0).max(1000),
  protein: z.number().finite().min(0).max(100),
  carbs: z.number().finite().min(0).max(100),
  fat: z.number().finite().min(0).max(100),
  fiber: z.number().finite().min(0).max(100).nullable(),
}).strict();
export const foodSchema = z.object({
  id: z.string().min(1).max(160), name: z.string().trim().min(1).max(160),
  per100g: nutrients, attribution: z.string().min(1).max(240),
}).strict();
export const recognitionSchema = z.object({
  mealType: z.enum(mealTypes),
  foods: z.array(z.object({
    name: z.string().trim().min(1).max(120),
    estimatedQuantity: z.number().finite().min(1).max(3000),
    unit: z.literal('g'), confidence: z.number().min(0).max(1),
    alternatives: z.array(z.string().min(1).max(120)).max(3),
    per100g: nutrients,
  }).strict()).max(12),
  analysisNotes: z.string().max(600), needsUserConfirmation: z.literal(true),
}).strict();
export const scanSchema = z.object({
  image: z.string().min(16).max(2800000),
  reference: z.boolean(), referenceDescription: z.string().max(120),
}).strict();
export const mealFoodSchema = z.object({
  food: foodSchema, grams: z.number().finite().min(1).max(3000),
  source: z.enum(['ai_estimate', 'user_entered']),
  confidence: z.number().min(0).max(1).nullable(),
}).strict();
export const mealSchema = z.object({
  id: z.string().uuid(), mealType: z.enum(mealTypes),
  eatenAt: z.iso.datetime({ offset: true }),
  foods: z.array(mealFoodSchema).min(1).max(12),
  imagePath: z.string().max(300).nullable(),
  timeZone: timeZoneSchema.optional(),
}).strict();
export const dateRangeSchema = z.object({
  start: z.iso.datetime({ offset: true }), end: z.iso.datetime({ offset: true }),
}).strict().refine(v => {
  const diff = Date.parse(v.end) - Date.parse(v.start);
  return diff > 0 && diff <= 32 * 86400000 + 7200000;
}, 'Date range must be at most 32 days');
export const toolNames = [
  'getUserProfile', 'getDailyNutrition', 'getNutritionForDate', 'getMealHistory',
  'getWeeklySummary', 'getMonthlySummary', 'getDailyTarget', 'searchFood',
  'getYearlySummary',
  'getConversationHistory',
  'addMeal', 'updateMeal', 'deleteMeal',
];
export const chatSchema = z.object({
  message: z.string().trim().min(1).max(2000),
  requestId: z.string().uuid().optional(),
  timeZone: timeZoneSchema.optional(),
  start: z.iso.datetime({ offset: true }), end: z.iso.datetime({ offset: true }),
}).strict().refine(v => {
  const diff = Date.parse(v.end) - Date.parse(v.start);
  return diff >= 23 * 3600000 && diff <= 25 * 3600000;
}, 'Supply one local calendar day');
export const assistantOutput = z.object({
  text: z.string().min(1).max(6000),
  tool: z.object({ name: z.enum(toolNames), arguments: z.record(z.string(), z.unknown()) }).strict().nullable(),
}).strict();
export const identity = "I'm Broget AI Health Assistant, the AI health and nutrition assistant built into the Broget AI application.";
const identityQuestion = /\b(gemini|chatgpt|openai|model|provider|system prompt|api key|api are you|who (created|made|built|trained) you|which ai|what ai|underlying technology)\b/i;
export function directAnswer(message) {
  if (identityQuestion.test(message)) return identity;
  if (/chest pain|cannot breathe|can't breathe|stroke|overdose|severe bleeding/i.test(message)) {
    return 'These symptoms may be an emergency. Please seek urgent medical care or call your local emergency number now. I can help with nutrition tracking, but cannot assess an emergency.';
  }
  if (/diagnos|prescri|medication|treat my|cure |pregnan|eating disorder|starv|purge|underweight/i.test(message)) {
    return 'I can help review recorded nutrition, but cannot diagnose conditions, prescribe treatment, or set a safe diet for pregnancy or an eating disorder. Please consult a qualified healthcare professional for individual guidance.';
  }
  return null;
}
export function safeText(text) {
  if (identityQuestion.test(text) || /AIza[\w-]+|-----BEGIN|https?:\/\/|system[_ -]?instruction|firestore|bearer\s+\S+/i.test(text)) return identity;
  return text;
}
export function totalMeals(meals) {
  const totals = { calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, fiberComplete: true, meals: meals.length };
  for (const meal of meals) for (const item of meal.foods) {
    for (const key of ['calories', 'protein', 'carbs', 'fat', 'fiber']) {
      const value = item.food.per100g[key];
      if (value == null) { if (key === 'fiber') totals.fiberComplete = false; }
      else totals[key] += value * item.grams / 100;
    }
  }
  return totals;
}
