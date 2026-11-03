import { readFile } from 'node:fs/promises';

const config = JSON.parse((await readFile(new URL('../config/production.local.json', import.meta.url), 'utf8')).replace(/^\uFEFF/, ''));
const response = await fetch(`https://identitytoolkit.googleapis.com/v1/projects?key=${encodeURIComponent(config.FIREBASE_API_KEY)}`, { signal: AbortSignal.timeout(15000) });
if (!response.ok) {
  console.error(`Firebase public configuration check failed (HTTP ${response.status}). Check the API key restrictions and Authentication setup.`);
  process.exitCode = 1;
} else {
  const result = await response.json();
  // Identity Toolkit returns the numeric project number in its projectId field.
  if (![config.FIREBASE_PROJECT_ID, config.FIREBASE_MESSAGING_SENDER_ID].includes(result.projectId)) throw new Error('Firebase public project identifier does not match the expected configuration');
  console.log(`Live Firebase project configuration verified: ${config.FIREBASE_PROJECT_ID}`);
  console.log(`Authorized auth domains: ${(result.authorizedDomains ?? []).join(', ')}`);
  console.log('This read-only check does not test registration, password-reset email delivery or App Check.');
}
