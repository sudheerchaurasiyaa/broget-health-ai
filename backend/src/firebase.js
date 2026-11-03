import { initializeApp, getApps, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { getAppCheck } from 'firebase-admin/app-check';

export const development = process.env.APP_ENV === 'development';
if (!getApps().length) initializeApp({
  projectId: process.env.GCLOUD_PROJECT,
  ...(development && process.env.FIRESTORE_EMULATOR_HOST ? {} : { credential: applicationDefault() }),
});
export const db = getFirestore();
export const auth = getAuth();
export { Timestamp, FieldValue };

export class ApiError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}
export async function authenticate(req, res, next) {
  try {
    const token = /^Bearer (.+)$/.exec(req.headers.authorization ?? '')?.[1];
    if (!token) throw new ApiError(401, 'sign-in-required');
    const decoded = await auth.verifyIdToken(token, true);
    if (!development) {
      const appToken = req.headers['x-firebase-appcheck'];
      if (typeof appToken !== 'string') throw new ApiError(403, 'attestation-required');
      await getAppCheck().verifyToken(appToken);
    }
    req.uid = decoded.uid;
    req.authTime = decoded.auth_time;
    req.verified = decoded.email_verified === true;
    req.admin = decoded.admin === true;
    req.userRef = db.doc(`users/${decoded.uid}`);
    const profile = await req.userRef.get();
    const deleting = profile.data()?.deleting || (await db.doc(`deletionLocks/${decoded.uid}`).get()).exists;
    if (deleting && req.path !== '/account') throw new ApiError(403, 'account-deleting');
    next();
  } catch (error) { next(error instanceof ApiError ? error : new ApiError(401, 'sign-in-required')); }
}
export async function quota(uid, action, limit, seconds = 3600) {
  const window = Math.floor(Date.now() / (seconds * 1000));
  const ref = db.doc(`privateQuotas/${uid}_${action}_${window}`);
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if ((snap.data()?.count ?? 0) >= limit) throw new ApiError(429, 'rate-limited');
    tx.set(ref, { count: (snap.data()?.count ?? 0) + 1, expiresAt: Timestamp.fromMillis((window + 2) * seconds * 1000) });
  });
}
