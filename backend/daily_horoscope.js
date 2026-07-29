/** Günlük burç yayınlama + kullanıcı bildirimleri. */
const admin = require('firebase-admin');
const { getFirestore, isFcmReady, sendNotification } = require('./fcm');

const COLLECTION = 'daily_horoscopes';

const ZODIACS = [
  'Koç',
  'Boğa',
  'İkizler',
  'Yengeç',
  'Aslan',
  'Başak',
  'Terazi',
  'Akrep',
  'Yay',
  'Oğlak',
  'Kova',
  'Balık',
];

/** Türkiye UTC+3 (DST yok). */
function istanbulDateKey(date = new Date()) {
  const shifted = new Date(date.getTime() + 3 * 60 * 60 * 1000);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const d = String(shifted.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function normalizeSigns(input) {
  if (!input || typeof input !== 'object') {
    const err = new Error('signs objesi gerekli');
    err.code = 'invalid_signs';
    throw err;
  }
  const signs = {};
  for (const zodiac of ZODIACS) {
    const raw = input[zodiac];
    const text = typeof raw === 'string' ? raw.trim() : '';
    if (!text) {
      const err = new Error(`${zodiac} yorumu boş olamaz`);
      err.code = 'empty_sign';
      err.zodiac = zodiac;
      throw err;
    }
    if (text.length > 800) {
      const err = new Error(`${zodiac} yorumu çok uzun (max 800 karakter)`);
      err.code = 'sign_too_long';
      err.zodiac = zodiac;
      throw err;
    }
    signs[zodiac] = text;
  }
  return signs;
}

function previewBody(text) {
  const oneLine = text.replace(/\s+/g, ' ').trim();
  if (oneLine.length <= 110) return oneLine;
  return `${oneLine.slice(0, 107)}...`;
}

async function getDailyHoroscope(dateKey) {
  const db = getFirestore();
  if (!db) {
    const err = new Error('Firestore hazır değil');
    err.code = 'firestore_unavailable';
    throw err;
  }
  const snap = await db.collection(COLLECTION).doc(dateKey).get();
  if (!snap.exists) return null;
  return { id: snap.id, ...snap.data() };
}

async function collectTokensForZodiac(zodiac) {
  const db = getFirestore();
  const snap = await db.collection('users').where('zodiac', '==', zodiac).get();
  const tokens = [];
  const tokenToUid = new Map();
  for (const doc of snap.docs) {
    const token = doc.data()?.fcmToken;
    if (typeof token === 'string' && token.trim()) {
      const t = token.trim();
      tokens.push(t);
      tokenToUid.set(t, doc.id);
    }
  }
  return { tokens, tokenToUid, userCount: snap.size };
}

async function notifyZodiacUsers({ zodiac, text, dateKey }) {
  if (!isFcmReady()) {
    return { sent: 0, failed: 0, users: 0, skipped: 'fcm_not_configured' };
  }

  const { tokens, tokenToUid, userCount } = await collectTokensForZodiac(zodiac);
  if (tokens.length === 0) {
    return { sent: 0, failed: 0, users: userCount };
  }

  const title = `${zodiac} — bugünkü burç yorumun`;
  const body = previewBody(text);
  const data = {
    type: 'daily_horoscope',
    date: dateKey,
    zodiac,
  };

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
          title,
          body,
          data,
          userId: uid,
        });
        if (id) sent += 1;
        else failed += 1;
      }),
    );
  }

  return { sent, failed, users: userCount };
}

async function publishDailyHoroscope({
  signs: rawSigns,
  adminUid,
  dateKey: rawDateKey,
  sendNotifications = true,
}) {
  const dateKey =
    typeof rawDateKey === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(rawDateKey)
      ? rawDateKey
      : istanbulDateKey();
  const signs = normalizeSigns(rawSigns);
  const db = getFirestore();
  if (!db) {
    const err = new Error('Firestore hazır değil');
    err.code = 'firestore_unavailable';
    throw err;
  }

  const payload = {
    date: dateKey,
    signs,
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    publishedBy: adminUid,
  };

  await db.collection(COLLECTION).doc(dateKey).set(payload, { merge: true });

  const notifyStats = {};
  if (sendNotifications) {
    for (const zodiac of ZODIACS) {
      notifyStats[zodiac] = await notifyZodiacUsers({
        zodiac,
        text: signs[zodiac],
        dateKey,
      });
    }
  }

  return {
    date: dateKey,
    signs,
    notifyStats,
  };
}

module.exports = {
  COLLECTION,
  ZODIACS,
  istanbulDateKey,
  getDailyHoroscope,
  publishDailyHoroscope,
};
