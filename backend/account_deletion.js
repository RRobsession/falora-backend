const admin = require('firebase-admin');
const { getFirestore, initFirebaseAdmin } = require('./fcm');

const REQUESTS_COLLECTION = 'account_deletion_requests';
const SUPPORT_EMAIL = 'prserdar.cakir@gmail.com';
const APP_DISPLAY_NAME = 'Tombik Teyze';
const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';

const USER_SCOPED_COLLECTIONS = [
  { name: 'fortunes', field: 'userId' },
  { name: 'couples', field: 'userId' },
  { name: 'manual_fortune_requests', field: 'userId' },
  { name: 'play_purchases', field: 'uid' },
  { name: 'notification_schedules', field: 'uid' },
];

function isValidEmail(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function normalizeEmail(email) {
  return String(email).trim().toLowerCase();
}

async function deleteQueryDocs(firestore, collectionName, field, value) {
  const snap = await firestore
    .collection(collectionName)
    .where(field, '==', value)
    .get();

  if (snap.empty) return 0;

  let deleted = 0;
  let batch = firestore.batch();
  let ops = 0;

  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    ops += 1;
    deleted += 1;
    if (ops >= 450) {
      await batch.commit();
      batch = firestore.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
  }

  return deleted;
}

async function deleteUserScopedData(firestore, uid) {
  const summary = {};

  for (const entry of USER_SCOPED_COLLECTIONS) {
    summary[entry.name] = await deleteQueryDocs(
      firestore,
      entry.name,
      entry.field,
      uid,
    );
  }

  await firestore.collection('users').doc(uid).delete().catch(() => {});
  summary.users = 1;

  return summary;
}

async function findAuthUserByEmail(email) {
  try {
    return await admin.auth().getUserByEmail(email);
  } catch (error) {
    if (error?.code === 'auth/user-not-found') {
      return null;
    }
    throw error;
  }
}

async function processAccountDeletionRequest({ email, source = 'web' }) {
  if (!isValidEmail(email)) {
    const error = new Error('Geçerli bir e-posta adresi girin.');
    error.statusCode = 400;
    throw error;
  }

  if (!initFirebaseAdmin()) {
    const error = new Error(
      'Hesap silme servisi şu an kullanılamıyor. Lütfen daha sonra tekrar deneyin.',
    );
    error.statusCode = 503;
    throw error;
  }

  const firestore = getFirestore();
  if (!firestore) {
    const error = new Error('Hesap silme servisi şu an kullanılamıyor.');
    error.statusCode = 503;
    throw error;
  }

  const normalizedEmail = normalizeEmail(email);
  const requestRef = firestore.collection(REQUESTS_COLLECTION).doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  await requestRef.set({
    email: normalizedEmail,
    appName: APP_DISPLAY_NAME,
    packageName: PACKAGE_NAME,
    source,
    status: 'received',
    createdAt: now,
    updatedAt: now,
  });

  let authUser = null;
  let deletedCollections = null;
  let status = 'completed_no_account';

  try {
    authUser = await findAuthUserByEmail(normalizedEmail);

    if (authUser) {
      deletedCollections = await deleteUserScopedData(firestore, authUser.uid);
      await admin.auth().deleteUser(authUser.uid);
      status = 'completed';
    }

    await requestRef.set(
      {
        status,
        uid: authUser?.uid || null,
        deletedCollections,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (error) {
    await requestRef.set(
      {
        status: 'failed',
        error: error.message || String(error),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    throw error;
  }

  console.log(
    `[account-deletion] email=${normalizedEmail} status=${status} uid=${authUser?.uid || 'none'}`,
  );

  return {
    ok: true,
    status,
    requestId: requestRef.id,
    message:
      'Hesap silme talebiniz alındı. Tombik Teyze hesabınız ve ilişkili kişisel verileriniz silinmiştir. Hesap bulunamadıysa talep kayda alınmıştır.',
    supportEmail: SUPPORT_EMAIL,
  };
}

module.exports = {
  processAccountDeletionRequest,
  APP_DISPLAY_NAME,
  PACKAGE_NAME,
  SUPPORT_EMAIL,
};
