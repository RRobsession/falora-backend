/** Tüm kullanıcılara FCM broadcast. */
const admin = require('firebase-admin');
const { getFirestore, isFcmReady, sendNotification } = require('./fcm');
const { isAdminUser } = require('./admin_config');

async function collectAllPushTokens() {
  const db = getFirestore();
  if (!db) {
    const err = new Error('Firestore hazır değil');
    err.code = 'firestore_unavailable';
    throw err;
  }

  const snap = await db.collection('users').get();
  const tokens = [];
  const tokenToUid = new Map();
  let usersWithToken = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (isAdminUser(doc.id, data.email)) continue;
    const token = data.fcmToken;
    if (typeof token === 'string' && token.trim()) {
      const t = token.trim();
      tokens.push(t);
      tokenToUid.set(t, doc.id);
      usersWithToken += 1;
    }
  }

  return {
    tokens,
    tokenToUid,
    totalUsers: snap.size,
    usersWithToken,
  };
}

async function broadcastNotification({
  title,
  body,
  adminUid,
}) {
  const cleanTitle = typeof title === 'string' ? title.trim() : '';
  const cleanBody = typeof body === 'string' ? body.trim() : '';

  if (!cleanTitle) {
    const err = new Error('Başlık gerekli');
    err.code = 'invalid_title';
    throw err;
  }
  if (!cleanBody) {
    const err = new Error('Bildirim metni gerekli');
    err.code = 'invalid_body';
    throw err;
  }
  if (cleanTitle.length > 80) {
    const err = new Error('Başlık çok uzun (max 80 karakter)');
    err.code = 'title_too_long';
    throw err;
  }
  if (cleanBody.length > 500) {
    const err = new Error('Metin çok uzun (max 500 karakter)');
    err.code = 'body_too_long';
    throw err;
  }

  if (!isFcmReady()) {
    const err = new Error('FCM yapılandırılmamış');
    err.code = 'fcm_not_configured';
    throw err;
  }

  const { tokens, tokenToUid, totalUsers, usersWithToken } =
    await collectAllPushTokens();

  let sent = 0;
  let failed = 0;
  const chunkSize = 400;

  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (token) => {
        const uid = tokenToUid.get(token);
        const id = await sendNotification({
          token,
          title: cleanTitle,
          body: cleanBody,
          data: {
            type: 'admin_broadcast',
          },
          userId: uid,
        });
        if (id) sent += 1;
        else failed += 1;
      }),
    );
  }

  const db = getFirestore();
  if (db) {
    try {
      await db.collection('admin_broadcasts').add({
        title: cleanTitle,
        body: cleanBody,
        sent,
        failed,
        totalUsers,
        usersWithToken,
        publishedBy: adminUid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.warn('BROADCAST LOG SKIP:', err.message);
    }
  }

  return {
    sent,
    failed,
    totalUsers,
    usersWithToken,
  };
}

module.exports = {
  broadcastNotification,
};
