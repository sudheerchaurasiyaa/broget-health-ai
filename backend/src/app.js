import express from 'express';
import cors from 'cors';
import sharp from 'sharp';
import { z } from 'zod';
import { randomUUID, createHash } from 'node:crypto';
import { authenticate, development, quota, ApiError, db, auth, FieldValue, Timestamp } from './firebase.js';
import { scanSchema, chatSchema, directAnswer, foodSchema, dateRangeSchema, mealSchema } from './contracts.js';
import { provider } from './provider.js';
import { searchFood, resolveFood } from './nutrition.js';
import { authorizedContext, executeTool, mealsForRange } from './tools.js';
import { totalMeals } from './contracts.js';
import { AiTransportError } from './ai_transport.js';
import { timeZoneSchema, reportRangeSchema, localDateKey } from './calendar.js';
import { mutateMeal, prepareReports, readReport } from './report_store.js';
import { compactReport } from './assistant_context.js';
import { beginTurn, finishTurn, failTurn } from './chat_store.js';
import { reminderPreferencesSchema, defaultReminders, generateRemindersForUser } from './reminders.js';

if (!development && (process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_STORAGE_EMULATOR_HOST)) throw new Error('Production cannot use emulators');
export const app = express();
app.disable('x-powered-by');
app.use((req, res, next) => {
  res.set('Cache-Control', 'no-store');
  res.set('X-Content-Type-Options', 'nosniff');
  res.set('X-Request-ID', randomUUID());
  next();
});
const allowed = (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean);
async function writePrivate(req, ref, data) {
  await db.runTransaction(async tx => {
    const [user, lock] = await tx.getAll(req.userRef, db.doc(`deletionLocks/${req.uid}`));
    if (!user.exists || user.data().deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    tx.set(ref, data);
  });
}
app.use(cors({ origin: (origin, done) => done(null, !origin || allowed.includes(origin)), methods: ['GET', 'POST', 'DELETE', 'PUT'], allowedHeaders: ['Content-Type', 'Authorization', 'X-Firebase-AppCheck'] }));
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.use(express.json({ limit: '3mb' }));
app.use(authenticate);
app.use(async (req, res, next) => {
  try {
    if (!development && !req.verified && ['/analyze','/chat','/summary','/foods'].includes(req.path)) throw new ApiError(403, 'verify-email');
    await quota(req.uid, 'requests', 600);
    next();
  } catch (error) { next(error); }
});

app.get('/foods', async (req, res) => {
  const q = z.string().trim().min(2).max(100).parse(req.query.q);
  await quota(req.uid, 'food-search', 120);
  res.json({ foods: await searchFood(q) });
});
app.put('/meals/:id', async (req, res) => {
  const input = mealSchema.parse(req.body);
  if (input.id !== req.params.id) throw new ApiError(400, 'invalid-input');
  const when = new Date(input.eatenAt);
  if (when < new Date('2020-01-01') || when.getTime() > Date.now() + 300000) throw new ApiError(400, 'invalid-input');
  if (input.imagePath !== null) throw new ApiError(400, 'photo-storage-unavailable');
  const foods = [];
  for (const item of input.foods) {
    const resolved = await resolveFood(item.food, req.uid);
    const { nutritionSource, ...food } = resolved;
    foods.push({ ...item, food, nutritionSource });
  }
  await mutateMeal(req.uid, input.id, { mealType: input.mealType, eatenAt: Timestamp.fromDate(when), foods,
    imagePath: input.imagePath, analysisVersion: 1 }, input.timeZone ?? 'UTC');
  res.json({ ok: true });
});
app.delete('/meals/:id', async (req, res) => {
  const id = z.string().uuid().parse(req.params.id);
  await mutateMeal(req.uid, id, null);
  res.json({ ok: true });
});
app.post('/analyze', async (req, res) => {
  const input = scanSchema.parse(req.body);
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(input.image)) throw new ApiError(400, 'invalid-image');
  const bytes = Buffer.from(input.image, 'base64');
  if (bytes.length > 2 * 1024 * 1024) throw new ApiError(413, 'image-too-large');
  const image = sharp(bytes, { limitInputPixels: 16000000, animated: false });
  let metadata;
  try { metadata = await image.metadata(); } catch { throw new ApiError(400, 'invalid-image'); }
  if (!['jpeg', 'png', 'webp'].includes(metadata.format) || !metadata.width || !metadata.height || (metadata.pages ?? 1) > 1) throw new ApiError(400, 'invalid-image');
  const compressed = await image.rotate().resize(1280, 1280, { fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 78 }).toBuffer();
  const hash = createHash('sha256').update('nutrition-v2').update(compressed).update(JSON.stringify([input.reference, input.referenceDescription])).digest('hex');
  const ref = db.doc(`users/${req.uid}/analyses/${hash}`);
  const cached = (await ref.get()).data();
  if (cached?.expiresAt.toMillis() > Date.now()) return res.json(cached.result);
  await quota(req.uid, 'scans', 20);
  await quota(req.uid, 'scan-throttle', 1, 8);
  const result = await provider.analyzeFoodImage(compressed, input.reference, input.referenceDescription);
  // Store only structured estimates, never the photo. These immutable private
  // snapshots let meal writes verify AI values and let old meals remain editable.
  const snapshotId = createHash('sha256').update(hash).update(randomUUID()).digest('hex');
  result.foods = result.foods.map((food, index) => {
    const nutrition = foodSchema.parse({
      id: `ai:${snapshotId}:${index}`, name: food.name,
      per100g: food.per100g, attribution: 'AI photo estimate · user reviewed',
    });
    return { ...food, nutrition };
  });
  await db.runTransaction(async tx => {
    const [user, lock] = await tx.getAll(req.userRef, db.doc(`deletionLocks/${req.uid}`));
    if (!user.exists || user.data().deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    for (const food of result.foods) tx.set(db.doc(`users/${req.uid}/scanFoods/${food.nutrition.id}`), { food: food.nutrition });
    tx.set(ref, { result, expiresAt: Timestamp.fromMillis(Date.now() + 3600000) });
  });
  res.json(result);
});
app.post('/chat', async (req, res) => {
  const input = chatSchema.parse(req.body);
  const id = input.requestId ?? randomUUID();
  await quota(req.uid, 'chat', 60);
  const cached = await beginTurn(req.uid, id, input.message);
  if (cached) return res.json(cached);
  try {
    await quota(req.uid, 'chat-throttle', 1, 3);
    const instant = directAnswer(input.message);
    let reply;
    if (instant) reply = { text: instant, proposal: null };
    else {
      const prepared = await prepareReports(req.uid, input.timeZone ?? 'UTC');
      if (!prepared.complete) throw new ApiError(409, 'reports-indexing');
      const range = { start: input.start, end: input.end };
      const context = await authorizedContext(req.uid, range);
      let answer = await provider.chat(input.message, context);
      let proposal = null;
      if (answer.tool) {
        const result = await executeTool(req.uid, answer.tool, range);
        if (result?.requiresUserConfirmation) proposal = result;
        else answer = await provider.chat(input.message, context, result);
      }
      reply = { text: answer.text, proposal };
    }
    await finishTurn(req.uid, id, reply);
    res.json(reply);
  } catch (error) {
    await failTurn(req.uid, id);
    throw error;
  }
});
app.post('/summary', async (req, res) => {
  const range = reportRangeSchema.parse(req.body);
  await quota(req.uid, 'summaries', 12);
  const report = compactReport(await readReport(req.uid, range.startDate, range.endDate));
  const response = await provider.chat('Explain this deterministic report. Do not calculate new numerical statistics. Mention estimates and incomplete logging.', report);
  const insightId = randomUUID();
  await db.runTransaction(async tx => {
    const [user, lock] = await tx.getAll(req.userRef, db.doc(`deletionLocks/${req.uid}`));
    if (!user.exists || user.data().deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    tx.set(req.userRef.collection('reportNarratives').doc(insightId), { userId: req.uid, ...range, text: response.text,
      totals: report.totals, source: 'ai_explanation', createdAt: FieldValue.serverTimestamp() });
    tx.set(req.userRef.collection('engagementEvents').doc(insightId), { userId: req.uid,
      type: 'report_explained', subjectId: insightId, createdAt: FieldValue.serverTimestamp() });
  });
  res.json({ text: response.text });
});
app.delete('/chat', async (req, res) => {
  await db.recursiveDelete(req.userRef.collection('chat'));
  await db.recursiveDelete(req.userRef.collection('chatTurns'));
  res.json({ ok: true });
});
app.post('/reports/prepare', async (req, res) => {
  const { timeZone } = z.object({ timeZone: timeZoneSchema }).strict().parse(req.body);
  res.json(await prepareReports(req.uid, timeZone));
});
app.get('/reports', async (req, res) => {
  const range = reportRangeSchema.parse(req.query);
  res.json(await readReport(req.uid, range.startDate, range.endDate));
});
app.get('/assistant-memory', async (req, res) => {
  const doc = await req.userRef.collection('assistantMemory').doc('profile').get();
  res.json({ notes: doc.data()?.notes ?? '' });
});
app.put('/assistant-memory', async (req, res) => {
  const input = z.object({ notes: z.string().trim().max(1000) }).strict().parse(req.body);
  await writePrivate(req, req.userRef.collection('assistantMemory').doc('profile'), { ...input, userId: req.uid, source: 'user_confirmed', updatedAt: FieldValue.serverTimestamp() });
  res.json({ ok: true });
});
app.get('/reminders/preferences', async (req, res) => {
  const doc = await req.userRef.collection('reminderPreferences').doc('current').get();
  res.json(doc.exists ? reminderPreferencesSchema.parse(doc.data()) : defaultReminders);
});
app.put('/reminders/preferences', async (req, res) => {
  await writePrivate(req, req.userRef.collection('reminderPreferences').doc('current'), reminderPreferencesSchema.parse(req.body));
  res.json({ ok: true });
});
app.post('/notifications/check', async (req, res) => {
  z.object({}).strict().parse(req.body);
  await quota(req.uid, 'reminder-check', 30);
  res.json(await generateRemindersForUser(req.uid));
});
app.get('/notifications', async (req, res) => {
  const { cursor } = z.object({ cursor: z.string().regex(/^\d{4}-\d{2}-\d{2}_(meal|movement)$/).optional() }).strict().parse(req.query);
  let query = req.userRef.collection('notifications').orderBy('createdAt', 'desc').limit(20);
  if (cursor) {
    const previous = await req.userRef.collection('notifications').doc(cursor).get();
    if (!previous.exists) throw new ApiError(400, 'invalid-input');
    query = query.startAfter(previous);
  }
  const page = await query.get();
  res.json({ notifications: page.docs.map(d => ({ id: d.id, ...d.data(), createdAt: d.data().createdAt.toDate().toISOString() })),
    nextCursor: page.size === 20 ? page.docs.at(-1).id : null });
});
app.post('/notifications/:id/action', async (req, res) => {
  const id = z.string().regex(/^\d{4}-\d{2}-\d{2}_(meal|movement)$/).parse(req.params.id);
  const { action } = z.object({ action: z.enum(['opened', 'dismissed', 'completed']) }).strict().parse(req.body);
  const ref = req.userRef.collection('notifications').doc(id);
  await db.runTransaction(async tx => {
    const [notification, user, lock] = await tx.getAll(ref, req.userRef, db.doc(`deletionLocks/${req.uid}`));
    if (!user.exists || user.data().deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    if (!notification.exists) throw new ApiError(404, 'not-found');
    tx.update(ref, { status: action, updatedAt: FieldValue.serverTimestamp() });
    tx.set(req.userRef.collection('engagementEvents').doc(`${id}_${action}`), { userId: req.uid,
      type: `reminder_${action}`, subjectId: id, createdAt: FieldValue.serverTimestamp() });
  });
  res.json({ ok: true });
});
app.delete('/account', async (req, res) => {
  if (Date.now() / 1000 - req.authTime > 300) throw new ApiError(401, 'recent-login-required');
  const { confirmation } = z.object({ confirmation: z.literal('DELETE') }).strict().parse(req.body);
  if (confirmation !== 'DELETE') throw new ApiError(400, 'confirmation-required');
  await db.doc(`deletionLocks/${req.uid}`).set({ createdAt: FieldValue.serverTimestamp() });
  await req.userRef.set({ deleting: true, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  // Keep the locked root until the Auth deletion succeeds, so the UI can resume
  // a partially completed deletion after fresh authentication.
  for (const collection of await req.userRef.listCollections()) await db.recursiveDelete(collection);
  await req.userRef.set({ userId: req.uid, name: '', health: null, deleting: true, updatedAt: FieldValue.serverTimestamp() });
  await auth.revokeRefreshTokens(req.uid);
  await auth.deleteUser(req.uid);
  await req.userRef.delete();
  res.json({ ok: true });
});
app.put('/admin/foods/:id', async (req, res) => {
  if (!req.admin) throw new ApiError(403, 'unauthorized');
  const id = z.string().regex(/^[a-z0-9_-]{1,100}$/).parse(req.params.id);
  const input = z.object({ food: foodSchema.omit({ id: true }), searchTerms: z.array(z.string().min(2).max(100)).min(1).max(50) }).strict().parse(req.body);
  await db.doc(`foods/${id}`).set({ ...input, updatedAt: FieldValue.serverTimestamp() });
  res.json({ ok: true });
});
app.get('/admin/metrics', async (req, res) => {
  if (!req.admin) throw new ApiError(403, 'unauthorized');
  res.json({ users: (await db.collection('users').count().get()).data().count });
});
app.use((req, res) => res.status(404).json({ code: 'not-found' }));
app.use((error, req, res, next) => {
  const status = error instanceof z.ZodError ? 400 : error.status ?? (error.name === 'TimeoutError' ? 504 : 500);
  const code = error instanceof z.ZodError ? 'invalid-input' : error instanceof ApiError || error instanceof AiTransportError ? error.code : status === 413 ? 'image-too-large' : status === 504 ? 'timeout' : 'service-unavailable';
  if (status >= 500) console.error(JSON.stringify({ event: 'request_failed', code, upstreamStatus: error instanceof AiTransportError ? error.upstreamStatus : undefined, requestId: res.get('X-Request-ID') }));
  res.status(status).json({ code });
});
