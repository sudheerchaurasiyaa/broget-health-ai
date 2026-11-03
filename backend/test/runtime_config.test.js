import test from 'node:test';
import assert from 'node:assert/strict';
import { validateHostedEnvironment } from '../src/runtime_config.js';

const valid = { APP_ENV: 'production', GCLOUD_PROJECT: 'broget-health-ai', AI_API_KEY: 'test-only', AI_MODEL: 'test-model', ALLOWED_ORIGINS: 'https://broget-health-ai.web.app', PORT: '10000' };
test('hosted API uses the hosting port and refuses emulator or incomplete configurations', () => {
  assert.deepEqual(validateHostedEnvironment(valid), { port: 10000 });
  for (const change of [
    { APP_ENV: 'development' }, { GCLOUD_PROJECT: 'demo-broget' },
    { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }, { FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099' },
    { AI_API_KEY: '' }, { AI_MODEL: '' }, { PORT: '-1' }, { PORT: 'NaN' },
    { ALLOWED_ORIGINS: '' }, { ALLOWED_ORIGINS: 'http://localhost:5173' },
    { ALLOWED_ORIGINS: 'https://example.com/' }, { ALLOWED_ORIGINS: 'https://example.com/path' },
  ]) assert.throws(() => validateHostedEnvironment({ ...valid, ...change }));
});
