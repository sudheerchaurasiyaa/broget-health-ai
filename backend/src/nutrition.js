import { foodSchema } from './contracts.js';
import { ApiError, db, Timestamp } from './firebase.js';
import { createHash } from 'node:crypto';

export function mapUsdaFood(row) {
  const find = (id) => {
    const n = row.foodNutrients?.find(n => n.nutrientId === id);
    return typeof n?.value === 'number' ? n.value : null;
  };
  const calories = find(1008), protein = find(1003), carbs = find(1005), fat = find(1004);
  if ([calories, protein, carbs, fat].some(n => n === null)) return null;
  return foodSchema.parse({
    id: `usda:${row.fdcId}`, name: row.description.slice(0, 160),
    per100g: { calories, protein, carbs, fat, fiber: find(1079) },
    attribution: `USDA FoodData Central / ${row.dataType} / FDC ${row.fdcId}`,
  });
}
export async function searchFood(query) {
  const normalized = query.trim().toLowerCase();
  const catalog = await db.collection('foods').where('searchTerms', 'array-contains', normalized).limit(12).get();
  const results = catalog.docs.map(doc => foodSchema.parse({ id: `catalog:${doc.id}`, ...doc.data().food }));
  if (!process.env.USDA_API_KEY) {
    if (results.length) return results;
    throw new ApiError(503, 'nutrition-not-configured');
  }
  const id = createHash('sha256').update(normalized).digest('hex');
  const cache = db.doc(`nutritionCache/${id}`);
  const cached = (await cache.get()).data();
  if (cached?.expiresAt?.toMillis() > Date.now()) {
    const batch = db.batch();
    for (const food of cached.foods) batch.set(db.doc(`nutritionFoods/${food.id}`), { food });
    if (cached.foods.length) await batch.commit();
    return [...results, ...cached.foods].slice(0, 20);
  }
  const response = await fetch('https://api.nal.usda.gov/fdc/v1/foods/search', {
    method: 'POST', headers: { 'content-type': 'application/json', 'X-Api-Key': process.env.USDA_API_KEY },
    body: JSON.stringify({ query: normalized, pageSize: 15, dataType: ['Foundation', 'SR Legacy', 'Survey (FNDDS)'] }),
    signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) throw new ApiError(503, 'nutrition-unavailable');
  const body = await response.json();
  const foods = (body.foods ?? []).flatMap(row => {
    try { const food = mapUsdaFood(row); return food ? [food] : []; } catch { return []; }
  });
  await cache.set({ foods, expiresAt: Timestamp.fromMillis(Date.now() + 86400000) });
  const batch = db.batch();
  for (const food of foods) batch.set(db.doc(`nutritionFoods/${food.id}`), { food });
  if (foods.length) await batch.commit();
  return [...results, ...foods].slice(0, 20);
}

export async function resolveFood(food, uid) {
  if (food.id.startsWith('ai:')) {
    if (!uid || !/^ai:[a-f0-9]{64}:\d{1,2}$/.test(food.id)) throw new ApiError(400, 'invalid-input');
    const snapshot = await db.doc(`users/${uid}/scanFoods/${food.id}`).get();
    if (!snapshot.exists) throw new ApiError(400, 'choose-food-again');
    return { ...foodSchema.parse(snapshot.data().food), nutritionSource: 'ai_estimate' };
  }
  if (food.id.startsWith('label:')) {
    if (!food.attribution.startsWith('User-entered label: ')) throw new ApiError(400, 'invalid-input');
    return { ...food, nutritionSource: 'user_entered' };
  }
  const catalog = food.id.startsWith('catalog:');
  if (!catalog && !/^usda:\d+$/.test(food.id)) throw new ApiError(400, 'invalid-input');
  const id = catalog ? food.id.slice(8) : food.id;
  if (id.includes('/')) throw new ApiError(400, 'invalid-input');
  const snap = await db.doc(`${catalog ? 'foods' : 'nutritionFoods'}/${id}`).get();
  if (!snap.exists) throw new ApiError(400, 'choose-food-again');
  return { ...foodSchema.parse({ id: food.id, ...snap.data().food }), nutritionSource: 'nutrition_database' };
}
