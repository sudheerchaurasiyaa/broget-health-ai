import { db, ApiError, FieldValue } from './firebase.js';

export async function beginTurn(uid, id, message) {
  const root = db.doc(`users/${uid}`), turn = root.collection('chatTurns').doc(id);
  return db.runTransaction(async tx => {
    const [previous, user, lock] = await tx.getAll(turn, root, db.doc(`deletionLocks/${uid}`));
    if (user.data()?.deleting || lock.exists) throw new ApiError(403, 'account-deleting');
    if (previous.exists && previous.data().message !== message) throw new ApiError(409, 'request-conflict');
    if (previous.data()?.status === 'complete') return previous.data().reply;
    if (previous.data()?.status === 'processing' && Date.now() - previous.data().updatedAt.toMillis() < 180000) throw new ApiError(409, 'assistant-request-in-progress');
    tx.set(turn, { userId: uid, message, status: 'processing', createdAt: previous.data()?.createdAt ?? FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    tx.set(root.collection('chat').doc(id), { userId: uid, role: 'user', text: message, verified: true,
      requestPending: true, createdAt: previous.data()?.createdAt ?? FieldValue.serverTimestamp() });
    return null;
  });
}
export async function finishTurn(uid, id, reply) {
  const root = db.doc(`users/${uid}`);
  await db.runTransaction(async tx => {
    const [user, lock, turn] = await tx.getAll(root, db.doc(`deletionLocks/${uid}`), root.collection('chatTurns').doc(id));
    if (user.data()?.deleting || lock.exists || !turn.exists) throw new ApiError(403, 'account-deleting');
    tx.update(root.collection('chatTurns').doc(id), { status: 'complete', reply, updatedAt: FieldValue.serverTimestamp() });
    tx.update(root.collection('chat').doc(id), { requestPending: false });
    tx.set(root.collection('chat').doc(`${id}_reply`), { userId: uid, role: 'assistant', text: reply.text,
      verified: true, createdAt: FieldValue.serverTimestamp() });
    tx.set(root.collection('engagementEvents').doc(`chat_${id}`), { userId: uid, type: 'assistant_exchange', subjectId: id, createdAt: FieldValue.serverTimestamp() });
  });
}
export async function failTurn(uid, id) {
  const ref = db.doc(`users/${uid}/chatTurns/${id}`);
  await db.runTransaction(async tx => { if ((await tx.get(ref)).exists) tx.update(ref, { status: 'failed', updatedAt: FieldValue.serverTimestamp() }); });
}
