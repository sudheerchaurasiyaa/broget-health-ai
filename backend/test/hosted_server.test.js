import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { once } from 'node:events';
import { generateKeyPairSync } from 'node:crypto';
import { mkdtemp, writeFile, unlink, rmdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

test('standalone hosted entry starts and protects API routes without using emulators', { timeout: 20000 }, async () => {
  const reservation = createServer();
  reservation.listen(0, '127.0.0.1');
  await once(reservation, 'listening');
  const port = reservation.address().port;
  await new Promise(resolve => reservation.close(resolve));
  const env = { ...process.env, APP_ENV: 'production', GCLOUD_PROJECT: 'broget-health-ai', AI_API_KEY: 'test-only', AI_MODEL: 'test-model', ALLOWED_ORIGINS: 'https://broget-health-ai.web.app', PORT: String(port) };
  for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST', 'GOOGLE_APPLICATION_CREDENTIALS']) delete env[key];
  // A generated test-only key prevents ADC from contacting a metadata server.
  // It cannot authenticate with Google and is never used for an API request.
  const directory = await mkdtemp(join(tmpdir(), 'broget-host-test-'));
  const credentialPath = join(directory, 'credential.json');
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  await writeFile(credentialPath, JSON.stringify({ type: 'service_account', project_id: 'broget-health-ai', client_email: 'test-only@broget-health-ai.iam.gserviceaccount.com', private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }) }));
  env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
  const child = spawn(process.execPath, ['src/server.js'], { cwd: new URL('../', import.meta.url), env, stdio: ['ignore', 'pipe', 'pipe'] });
  const exited = once(child, 'exit');
  try {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Hosted API did not start')), 12000);
      child.stdout.on('data', chunk => {
        if (chunk.toString().includes('BROGET hosted API ready')) { clearTimeout(timer); resolve(); }
      });
      child.once('exit', () => { clearTimeout(timer); reject(new Error('Hosted API exited before readiness')); });
      child.once('error', reject);
    });
    const url = `http://127.0.0.1:${port}`;
    const health = await fetch(`${url}/health`);
    assert.equal(health.status, 200); assert.deepEqual(await health.json(), { status: 'ok' });
    const protectedRequest = await fetch(`${url}/chat`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    assert.equal(protectedRequest.status, 401);
    assert.deepEqual(await protectedRequest.json(), { code: 'sign-in-required' });
  } finally {
    child.kill('SIGTERM');
    await exited;
    await unlink(credentialPath);
    await rmdir(directory);
  }
});
