import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { app } from './app.js';
export const api = onRequest({
  region: 'us-central1', timeoutSeconds: 180, memory: '512MiB',
  maxInstances: 5, concurrency: 20,
  secrets: [defineSecret('AI_API_KEY'), defineSecret('USDA_API_KEY')],
}, app);
