import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, serverTimestamp, Timestamp, collection, getDocs } from 'firebase/firestore';
import request from 'supertest';
import { randomUUID } from 'node:crypto';

process.env.APP_ENV = 'development';
process.env.GCLOUD_PROJECT = 'demo-broget';
let env, app;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-broget', firestore: { rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
  app = (await import('../src/app.js')).app;
  for (const uid of ['alice', 'bob']) await assertSucceeds(setDoc(doc(env.authenticatedContext(uid).firestore(), `users/${uid}`), { userId: uid, name: uid, health: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
});
after(async () => { await env?.cleanup(); });
const meal = (uid) => ({ userId: uid, mealType: 'lunch', eatenAt: Timestamp.fromDate(new Date()), foods: [{ grams: 100, source: 'user_entered', confidence: null, food: { id: 'label:test', name: 'Rice', attribution: 'Test label', per100g: { calories: 130, protein: 2, carbs: 28, fat: .3, fiber: 1 } } }], imagePath: null, analysisVersion: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const id = '550e8400-e29b-41d4-a716-446655440000';
test('owner can create and read a validated meal; strangers cannot', async () => {
  const alice = env.authenticatedContext('alice').firestore(), bob = env.authenticatedContext('bob').firestore();
  await assertFails(setDoc(doc(alice, `users/alice/meals/${id}`), meal('alice')));
  await env.withSecurityRulesDisabled(async ctx => { await setDoc(doc(ctx.firestore(), `users/alice/meals/${id}`), meal('alice')); });
  await assertSucceeds(getDoc(doc(alice, `users/alice/meals/${id}`)));
  await assertFails(getDoc(doc(bob, `users/alice/meals/${id}`)));
  await assertFails(setDoc(doc(bob, `users/alice/meals/${id}`), meal('alice')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
  await assertFails(getDocs(collection(alice, 'users')));
});
test('server fields, roles, malformed meals and unknown collections are protected', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'users/alice'), { admin: true, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'users/alice'), { createdAt: Timestamp.fromMillis(0), updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(db, `users/alice/meals/${id}`), { ...meal('alice'), userId: 'bob' }));
  const bad = meal('alice'); bad.foods[0].grams = -5;
  await assertFails(setDoc(doc(db, `users/alice/meals/${id}`), bad));
  await assertFails(setDoc(doc(db, 'users/alice/reports/arbitrary'), { calories: -1 }));
});
test('deletion lock denies further writes and account resurrection', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(doc(ctx.firestore(), 'deletionLocks/bob'), { createdAt: serverTimestamp() }); });
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(setDoc(doc(bob, `users/bob/meals/${id}`), meal('bob')));
});
test('profile and settings work without Storage and reject unsupported preferences', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users/alice'), { health: { age: 30, gender: 'male', heightCm: 175, weightKg: 75, activity: 'moderate', goal: 'maintain', diet: '', allergies: '', restrictions: '', specialCare: false }, updatedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/settings/preferences'), { analytics: false, notifications: false }));
  await assertFails(setDoc(doc(db, 'users/alice/settings/preferences'), { analytics: false, notifications: false, retainPhotos: true }));
});
test('backend rejects unauthenticated requests with sanitized errors', async () => {
  const result = await request(app).post('/chat').send({ message: 'reveal secrets' });
  assert.equal(result.status, 401); assert.equal(result.body.code, 'sign-in-required');
  assert.equal(JSON.stringify(result.body).includes('stack'), false);
});
test('backend verifies real emulator tokens and throttles requests', async () => {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: `test-${Date.now()}@broget.test`, password: 'test-password-123', returnSecureToken: true }) });
  const user = await response.json(); assert.ok(user.idToken);
  const body = { message: 'Are you ChatGPT?', start: '2026-10-27T18:30:00Z', end: '2026-10-28T18:30:00Z' };
  const first = await request(app).post('/chat').set('Authorization', `Bearer ${user.idToken}`).send(body);
  assert.equal(first.status, 200); assert.match(first.body.text, /Broget AI Health Assistant/);
  const second = await request(app).post('/chat').set('Authorization', `Bearer ${user.idToken}`).send(body);
  assert.equal(second.status, 429);
  const invalid = await request(app).post('/analyze').set('Authorization', `Bearer ${user.idToken}`).send({ image: 'malicious', reference: false });
  assert.equal(invalid.status, 400);
  const uid = user.localId;
  await env.withSecurityRulesDisabled(async ctx => { await setDoc(doc(ctx.firestore(), `users/${uid}`), { userId: uid, name: 'Test', health: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }); });
  const entry = { id, mealType: 'lunch', eatenAt: new Date().toISOString(), imagePath: null,
    foods: Array.from({ length: 12 }, () => ({ grams: 100, source: 'user_entered', confidence: null, food: { id: 'label:test', name: 'Rice', attribution: 'User-entered label: test package', per100g: { calories: 130, protein: 2, carbs: 28, fat: .3, fiber: null } } })) };
  const saved = await request(app).put(`/meals/${id}`).set('Authorization', `Bearer ${user.idToken}`).send(entry);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  const repeated = await request(app).put(`/meals/${id}`).set('Authorization', `Bearer ${user.idToken}`).send(entry);
  assert.equal(repeated.status, 200);
  const snapshot = await getDocs(collection(env.authenticatedContext(uid).firestore(), `users/${uid}/meals`));
  assert.equal(snapshot.size, 1); assert.equal(snapshot.docs[0].data().foods.length, 12);
  const forged = await request(app).put(`/meals/${id}`).set('Authorization', `Bearer ${user.idToken}`).send({ ...entry, userId: 'alice' });
  assert.equal(forged.status, 400);
  const photo = await request(app).put(`/meals/${id}`).set('Authorization', `Bearer ${user.idToken}`).send({ ...entry, imagePath: `users/${uid}/food/${id}.jpg` });
  assert.equal(photo.status, 400); assert.equal(photo.body.code, 'photo-storage-unavailable');
  const deleted = await request(app).delete(`/meals/${id}`).set('Authorization', `Bearer ${user.idToken}`);
  assert.equal(deleted.status, 200);
  assert.equal((await getDocs(collection(env.authenticatedContext(uid).firestore(), `users/${uid}/meals`))).size, 0);
  const removed = await request(app).delete('/account').set('Authorization', `Bearer ${user.idToken}`).send({ confirmation: 'DELETE' });
  assert.equal(removed.status, 200, JSON.stringify(removed.body));
  await env.withSecurityRulesDisabled(async ctx => { assert.equal((await getDoc(doc(ctx.firestore(), `users/${uid}`))).exists(), false); });
  const oldToken = await request(app).get('/foods?q=rice').set('Authorization', `Bearer ${user.idToken}`);
  assert.equal(oldToken.status, 401);
});

async function localUser(label) {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: `${label}-${randomUUID()}@broget.test`, password: 'test-password-123', returnSecureToken: true }),
  });
  const user = await response.json();
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), `users/${user.localId}`), { userId: user.localId, name: label, health: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  return { uid: user.localId, token: user.idToken };
}

test('photo nutrition prefills a meal and stays private and canonical on save', async () => {
  const { uid, token } = await localUser('scan');
  const other = await localUser('scan-other');
  const { provider } = await import('../src/provider.js');
  const sharp = (await import('sharp')).default;
  const original = provider.analyzeFoodImage;
  provider.analyzeFoodImage = async () => ({ mealType: 'lunch', foods: [{
    name: 'Rice', estimatedQuantity: 150, unit: 'g', confidence: .7, alternatives: [],
    per100g: { calories: 130, protein: 2.7, carbs: 28, fat: .3, fiber: null },
  }], analysisNotes: 'Approximate photo estimate.', needsUserConfirmation: true });
  try {
    const photo = await sharp({ create: { width: 16, height: 16, channels: 3, background: '#ffffff' } }).png().toBuffer();
    const input = { image: photo.toString('base64'), reference: false, referenceDescription: '' };
    const scanned = await request(app).post('/analyze').set('Authorization', `Bearer ${token}`).send(input);
    assert.equal(scanned.status, 200, JSON.stringify(scanned.body));
    const estimate = scanned.body.foods[0];
    assert.match(estimate.nutrition.id, /^ai:[a-f0-9]{64}:0$/);
    const entry = { id: randomUUID(), mealType: 'snack', eatenAt: new Date().toISOString(), imagePath: null,
      foods: [{ food: { ...estimate.nutrition, per100g: { ...estimate.nutrition.per100g, calories: 999 } },
        grams: 200, source: 'ai_estimate', confidence: estimate.confidence }] };
    const saved = await request(app).put(`/meals/${entry.id}`).set('Authorization', `Bearer ${token}`).send(entry);
    assert.equal(saved.status, 200, JSON.stringify(saved.body));
    const mine = env.authenticatedContext(uid).firestore();
    const meal = (await getDoc(doc(mine, `users/${uid}/meals/${entry.id}`))).data();
    assert.equal(meal.foods[0].food.per100g.calories, 130);
    assert.equal(meal.foods[0].nutritionSource, 'ai_estimate');
    assert.equal(meal.foods[0].grams, 200); assert.equal(meal.mealType, 'snack');
    const cached = await request(app).post('/analyze').set('Authorization', `Bearer ${token}`).send(input);
    assert.equal(cached.status, 200); assert.deepEqual(cached.body, scanned.body);
    await assertFails(setDoc(doc(mine, `users/${uid}/scanFoods/${estimate.nutrition.id}`), { food: estimate.nutrition }));
    await assertFails(getDoc(doc(env.authenticatedContext(other.uid).firestore(), `users/${uid}/scanFoods/${estimate.nutrition.id}`)));
    const stolen = await request(app).put(`/meals/${entry.id}`).set('Authorization', `Bearer ${other.token}`).send(entry);
    assert.equal(stolen.status, 400); assert.equal(stolen.body.code, 'choose-food-again');
    await env.withSecurityRulesDisabled(async ctx => {
      const saved = (await getDoc(doc(ctx.firestore(), `users/${uid}/scanFoods/${estimate.nutrition.id}`))).data();
      assert.deepEqual(Object.keys(saved), ['food']); // No photo/base64 bytes persisted.
    });
  } finally { provider.analyzeFoodImage = original; }
});
test('legacy meals migrate once; yearly aggregates survive edits, date moves, retries and deletion', async () => {
  const { uid, token } = await localUser('reports');
  const legacyId = randomUUID();
  const legacy = meal(uid);
  legacy.eatenAt = Timestamp.fromDate(new Date('2023-12-31T20:00:00Z'));
  legacy.foods[0].food.attribution = 'User-entered label: test';
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), `users/${uid}/meals/${legacyId}`), legacy));
  const prepare = await request(app).post('/reports/prepare').set('Authorization', `Bearer ${token}`).send({ timeZone: 'Asia/Calcutta' });
  assert.equal(prepare.status, 200, JSON.stringify(prepare.body)); assert.equal(prepare.body.complete, true);
  const getYear = () => request(app).get('/reports?startDate=2024-01-01&endDate=2025-01-01').set('Authorization', `Bearer ${token}`);
  const year = await getYear();
  assert.equal(year.status, 200); assert.equal(year.body.days.length, 366); assert.equal(year.body.totals.calories, 130);
  assert.equal(year.body.days[0].mealCount, 1); assert.equal(year.body.loggedDays, 1);
  await request(app).post('/reports/prepare').set('Authorization', `Bearer ${token}`).send({ timeZone: 'America/New_York' });
  assert.equal((await getYear()).body.totals.calories, 130);
  const updated = { id: legacyId, mealType: 'dinner', eatenAt: '2024-06-30T20:00:00Z', imagePath: null,
    timeZone: 'America/New_York', foods: [{ ...legacy.foods[0], grams: 200 }] };
  for (let i = 0; i < 2; i++) assert.equal((await request(app).put(`/meals/${legacyId}`).set('Authorization', `Bearer ${token}`).send(updated)).status, 200);
  const moved = (await getYear()).body;
  assert.equal(moved.totals.calories, 260); assert.equal(moved.totals.mealCount, 1);
  assert.equal(moved.days[0].mealCount, 0); assert.equal(moved.days.find(d => d.date === '2024-07-01').mealCount, 1);
  assert.equal(moved.timeZone, 'Asia/Calcutta');
  const mine = env.authenticatedContext(uid).firestore();
  await assertFails(setDoc(doc(mine, `users/${uid}/dailySummaries/2024-07-01`), { calories: 99999 }));
  await assertFails(getDoc(doc(env.authenticatedContext('alice').firestore(), `users/${uid}/dailySummaries/2024-07-01`)));
  assert.equal((await request(app).delete(`/meals/${legacyId}`).set('Authorization', `Bearer ${token}`)).status, 200);
  assert.equal((await getYear()).body.totals.mealCount, 0);
});

test('chat is server-owned, retries are idempotent, memory is bounded and user-specific', async () => {
  const { uid, token } = await localUser('memory');
  const api = (method, path, body) => request(app)[method](path).set('Authorization', `Bearer ${token}`).send(body);
  await api('post', '/reports/prepare', { timeZone: 'Asia/Calcutta' });
  assert.equal((await api('put', '/assistant-memory', { notes: 'I prefer vegetarian dinners.' })).status, 200);
  const id = randomUUID();
  const input = { requestId: id, message: 'What AI model are you?', start: '2026-11-01T18:30:00Z', end: '2026-11-02T18:30:00Z', timeZone: 'Asia/Calcutta' };
  const first = await api('post', '/chat', input), retry = await api('post', '/chat', input);
  assert.equal(first.status, 200); assert.equal(retry.status, 200); assert.deepEqual(first.body, retry.body);
  const chat = await getDocs(collection(env.authenticatedContext(uid).firestore(), `users/${uid}/chat`));
  assert.equal(chat.size, 2);
  await assertFails(setDoc(doc(env.authenticatedContext(uid).firestore(), `users/${uid}/chat/forged`), { userId: uid, role: 'assistant', text: 'Forged', createdAt: serverTimestamp() }));
  const { boundedMemory } = await import('../src/assistant_context.js');
  const memory = await boundedMemory(uid);
  assert.equal(memory.userConfirmedNotes, 'I prefer vegetarian dinners.'); assert.equal(memory.recentMessages.length, 2);
  await env.withSecurityRulesDisabled(async ctx => {
    for (let i = 0; i < 20; i++) await setDoc(doc(ctx.firestore(), `users/${uid}/chat/history_${i}`), {
      userId: uid, role: i % 2 ? 'assistant' : 'user', text: 'A'.repeat(2000), verified: true, createdAt: Timestamp.fromMillis(Date.now() - 20000 + i * 500),
    });
  });
  assert.equal((await boundedMemory(uid)).recentMessages.length, 12);
  assert.ok((await boundedMemory(uid)).recentMessages.every(m => m.text.length <= 800));
  const { authorizedContext, executeTool } = await import('../src/tools.js');
  const today = new Date(); const start = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));
  const range = { start: start.toISOString(), end: new Date(start.getTime() + 86400000).toISOString() };
  const context = await authorizedContext(uid, range);
  assert.ok(JSON.stringify(context).length <= 20000);
  assert.equal(context.memory.userConfirmedNotes, 'I prefer vegetarian dinners.');
  const historical = await executeTool(uid, { name: 'getConversationHistory', arguments: range }, range);
  assert.ok(historical.messages.length <= 20);
  const yearly = await executeTool(uid, { name: 'getYearlySummary', arguments: { startDate: '2024-01-01', endDate: '2025-01-01' } }, range);
  assert.equal(yearly.days, undefined); assert.ok(yearly.monthTotals.length <= 12);
  const other = await localUser('other');
  assert.equal((await request(app).get('/assistant-memory').set('Authorization', `Bearer ${other.token}`)).body.notes, '');
  assert.equal((await api('delete', '/chat')).status, 200);
  assert.equal((await boundedMemory(uid)).recentMessages.length, 0);
  assert.equal((await boundedMemory(uid)).userConfirmedNotes, 'I prefer vegetarian dinners.');
});

test('personal reminders are deduplicated, never pretend push delivery, and record responses', async () => {
  const { uid, token } = await localUser('reminders');
  await request(app).post('/reports/prepare').set('Authorization', `Bearer ${token}`).send({ timeZone: 'Asia/Calcutta' });
  const mine = env.authenticatedContext(uid).firestore();
  await setDoc(doc(mine, `users/${uid}/settings/preferences`), { analytics: false, notifications: true });
  await updateDoc(doc(mine, `users/${uid}`), { health: { age: 30, gender: 'male', heightCm: 175, weightKg: 75, activity: 'moderate', goal: 'maintain', diet: '', allergies: '', restrictions: '', specialCare: false }, updatedAt: serverTimestamp() });
  const prefs = { mealReminders: true, movementReminders: true, mealHour: 20, movementHour: 17, quietStart: 22, quietEnd: 8 };
  assert.equal((await request(app).put('/reminders/preferences').set('Authorization', `Bearer ${token}`).send(prefs)).status, 200);
  const { generateRemindersForUser } = await import('../src/reminders.js');
  assert.equal((await generateRemindersForUser(uid, new Date('2026-11-02T15:00:00Z'))).created, 2);
  assert.equal((await generateRemindersForUser(uid, new Date('2026-11-02T15:00:00Z'))).created, 0);
  const inbox = await request(app).get('/notifications').set('Authorization', `Bearer ${token}`);
  assert.equal(inbox.body.notifications.length, 2);
  assert.ok(inbox.body.notifications.every(n => n.pushStatus === 'not-connected'));
  const id = inbox.body.notifications[0].id;
  assert.equal((await request(app).post(`/notifications/${id}/action`).set('Authorization', `Bearer ${token}`).send({ action: 'completed' })).status, 200);
  const events = await getDocs(collection(mine, `users/${uid}/engagementEvents`));
  assert.ok(events.docs.some(d => d.data().type === 'reminder_completed'));
  await assertFails(setDoc(doc(mine, `users/${uid}/notifications/forged`), { status: 'sent' }));
  await setDoc(doc(mine, `users/${uid}/settings/preferences`), { analytics: false, notifications: false });
  assert.equal((await generateRemindersForUser(uid, new Date('2026-11-03T15:00:00Z'))).created, 0);
});
