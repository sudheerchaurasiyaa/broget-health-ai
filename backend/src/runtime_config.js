export function validateHostedEnvironment(env) {
  if (env.APP_ENV !== 'production') throw new Error('Hosted server requires APP_ENV=production');
  if (['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST'].some(key => env[key])) {
    throw new Error('Hosted server cannot use Firebase emulators');
  }
  if (!env.GCLOUD_PROJECT || env.GCLOUD_PROJECT.startsWith('demo-')) throw new Error('Set GCLOUD_PROJECT to the live Firebase project ID');
  if (!env.AI_API_KEY || !env.AI_MODEL) throw new Error('Set AI_API_KEY and AI_MODEL on the backend host');
  const origins = (env.ALLOWED_ORIGINS ?? '').split(',');
  if (!origins.length || origins.some(origin => {
    try {
      const url = new URL(origin);
      return url.protocol !== 'https:' || url.origin !== origin || ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
    } catch { return true; }
  })) throw new Error('Set ALLOWED_ORIGINS to comma-separated public HTTPS origins without trailing slashes');
  const port = Number(env.PORT ?? 8787);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PORT must be a valid TCP port');
  return { port };
}
