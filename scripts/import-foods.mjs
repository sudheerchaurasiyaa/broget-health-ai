// Import reviewed, licensed regional nutrition entries; never synthesize nutrients.
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { z } = require('zod');
import { foodSchema } from '../backend/src/contracts.js';
const filename = process.argv[2];
if (!filename) throw new Error('Usage: node scripts/import-foods.mjs <reviewed-catalog.json>');
const entries = z.array(z.object({ id: z.string().regex(/^[a-z0-9_-]{1,100}$/), food: foodSchema.omit({ id: true }), searchTerms: z.array(z.string().min(2).max(100)).min(1).max(50) }).strict()).max(10000).parse(JSON.parse(await readFile(filename, 'utf8')));
initializeApp({ projectId: process.env.GCLOUD_PROJECT, ...(process.env.FIRESTORE_EMULATOR_HOST ? {} : { credential: applicationDefault() }) });
const db = getFirestore();
for (let i=0; i<entries.length; i+=400) {
  const batch = db.batch();
  for (const { id, ...data } of entries.slice(i,i+400)) batch.set(db.doc(`foods/${id}`), data);
  await batch.commit();
}
console.log(`Imported ${entries.length} reviewed entries.`);
