/** Admin: e-posta ile kullanıcıya jeton yükleme. */
const admin = require('firebase-admin');
const { getFirestore, initFirebaseAdmin } = require('./fcm');

function normalizeEmail(email) {
  return String(email || '')
    .trim()
    .toLowerCase();
}

async function findUidByEmail(email) {
  const normalized = normalizeEmail(email);
  if (!normalized || !normalized.includes('@')) {
    const err = new Error('Geçerli bir e-posta girin');
    err.code = 'invalid_email';
    throw err;
  }

  if (!initFirebaseAdmin()) {
    const err = new Error('Firebase Admin hazır değil');
    err.code = 'firebase_unavailable';
    throw err;
  }

  try {
    const user = await admin.auth().getUserByEmail(normalized);
    return {
      uid: user.uid,
      email: user.email || normalized,
      name: user.displayName || '',
    };
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
  }

  const db = getFirestore();
  if (!db) {
    const err = new Error('Firestore hazır değil');
    err.code = 'firestore_unavailable';
    throw err;
  }

  const snap = await db
    .collection('users')
    .where('email', '==', normalized)
    .limit(1)
    .get();

  if (snap.empty) {
    const err = new Error('Bu e-posta ile kullanıcı bulunamadı');
    err.code = 'user_not_found';
    throw err;
  }

  const doc = snap.docs[0];
  const data = doc.data() || {};
  return {
    uid: doc.id,
    email: data.email || normalized,
    name: data.name || data.displayName || '',
  };
}

async function grantTokensByEmail({ email, amount, adminUid }) {
  const qty = Number(amount);
  if (!Number.isFinite(qty) || !Number.isInteger(qty) || qty <= 0) {
    const err = new Error('Jeton miktarı pozitif tam sayı olmalı');
    err.code = 'invalid_amount';
    throw err;
  }
  if (qty > 100000) {
    const err = new Error('Tek seferde en fazla 100000 jeton yüklenebilir');
    err.code = 'amount_too_large';
    throw err;
  }

  const user = await findUidByEmail(email);
  const db = getFirestore();
  if (!db) {
    const err = new Error('Firestore hazır değil');
    err.code = 'firestore_unavailable';
    throw err;
  }

  const ref = db.collection('users').doc(user.uid);
  let before = 0;
  let after = 0;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      const err = new Error('Kullanıcı profili bulunamadı');
      err.code = 'user_doc_missing';
      throw err;
    }
    const data = snap.data() || {};
    before = typeof data.tokens === 'number' ? data.tokens : Number(data.tokens) || 0;
    after = before + qty;
    tx.update(ref, {
      tokens: after,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  try {
    await db.collection('admin_token_grants').add({
      uid: user.uid,
      email: user.email,
      amount: qty,
      before,
      after,
      grantedBy: adminUid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.warn('ADMIN TOKEN GRANT LOG SKIP:', err.message);
  }

  return {
    uid: user.uid,
    email: user.email,
    name: user.name,
    amount: qty,
    before,
    after,
  };
}

module.exports = {
  grantTokensByEmail,
  findUidByEmail,
};
