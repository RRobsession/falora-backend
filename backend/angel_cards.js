/** Admin: melek kartı cümlelerini gruplara dağıtarak FCM gönderir. */
const admin = require('firebase-admin');
const { getFirestore, isFcmReady, sendNotification } = require('./fcm');
const { isAdminUser } = require('./admin_config');

const ALLOWED_GROUP_SIZES = [10, 20];
const MIN_CARDS = 2;
const MAX_CARDS = 50;
const MAX_CARD_LEN = 2200;
const MAX_TITLE_LEN = 80;
const ISTANBUL_OFFSET_MS = 3 * 60 * 60 * 1000;

function istanbulDayWindow(now = new Date()) {
  const shifted = new Date(now.getTime() + ISTANBUL_OFFSET_MS);
  const year = shifted.getUTCFullYear();
  const month = shifted.getUTCMonth();
  const day = shifted.getUTCDate();
  const dateKey = [
    year.toString().padStart(4, '0'),
    (month + 1).toString().padStart(2, '0'),
    day.toString().padStart(2, '0'),
  ].join('-');
  const expiresAt = new Date(
    Date.UTC(year, month, day + 1) - ISTANBUL_OFFSET_MS,
  );
  return { dateKey, expiresAt };
}

async function persistDailyAngelCards({ assignments, title, adminUid }) {
  const db = getFirestore();
  if (!db || assignments.length === 0) return;

  const { dateKey, expiresAt } = istanbulDayWindow();
  const chunkSize = 400;
  for (let i = 0; i < assignments.length; i += chunkSize) {
    const batch = db.batch();
    for (const assignment of assignments.slice(i, i + chunkSize)) {
      const ref = db
        .collection('users')
        .doc(assignment.uid)
        .collection('daily_angel_cards')
        .doc(dateKey);
      batch.set(ref, {
        dateKey,
        title,
        text: assignment.text,
        cardIndex: assignment.cardIndex,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        publishedBy: adminUid,
      });
    }
    await batch.commit();
  }
  return dateKey;
}

function shuffleInPlace(arr) {
  for (let i = arr.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

function normalizeCards(input) {
  if (!Array.isArray(input)) {
    const err = new Error('Kart listesi gerekli');
    err.code = 'invalid_cards';
    throw err;
  }
  const cards = input
    .map((c) => (typeof c === 'string' ? c.trim() : ''))
    .filter((c) => c.length > 0);

  if (cards.length < MIN_CARDS) {
    const err = new Error(`En az ${MIN_CARDS} melek kartı cümlesi girin`);
    err.code = 'too_few_cards';
    throw err;
  }
  if (cards.length > MAX_CARDS) {
    const err = new Error(`En fazla ${MAX_CARDS} melek kartı girebilirsiniz`);
    err.code = 'too_many_cards';
    throw err;
  }
  for (const c of cards) {
    if (c.length > MAX_CARD_LEN) {
      const err = new Error(`Kart metni çok uzun (max ${MAX_CARD_LEN})`);
      err.code = 'card_too_long';
      throw err;
    }
  }
  return cards;
}

async function collectTokenUsers() {
  const db = getFirestore();
  if (!db) {
    const err = new Error('Firestore hazır değil');
    err.code = 'firestore_unavailable';
    throw err;
  }

  const snap = await db.collection('users').get();
  const users = [];
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (isAdminUser(doc.id, data.email)) continue;
    const token = data.fcmToken;
    if (typeof token === 'string' && token.trim()) {
      users.push({ uid: doc.id, token: token.trim() });
    }
  }
  return { users, totalUsers: snap.size };
}

/**
 * Kullanıcıları karıştırır, groupSize'lık gruplara böler,
 * grup i → cards[i % cards.length] (round-robin).
 */
async function sendAngelCardNotifications({
  title,
  cards: rawCards,
  groupSize,
  adminUid,
}) {
  const cleanTitle = typeof title === 'string' ? title.trim() : '';
  if (!cleanTitle) {
    const err = new Error('Başlık gerekli');
    err.code = 'invalid_title';
    throw err;
  }
  if (cleanTitle.length > MAX_TITLE_LEN) {
    const err = new Error(`Başlık çok uzun (max ${MAX_TITLE_LEN})`);
    err.code = 'title_too_long';
    throw err;
  }

  const size = Number(groupSize);
  if (!ALLOWED_GROUP_SIZES.includes(size)) {
    const err = new Error('Grup boyutu 10 veya 20 olmalı');
    err.code = 'invalid_group_size';
    throw err;
  }

  const cards = normalizeCards(rawCards);

  if (!isFcmReady()) {
    const err = new Error('FCM yapılandırılmamış');
    err.code = 'fcm_not_configured';
    throw err;
  }

  const { users, totalUsers } = await collectTokenUsers();
  shuffleInPlace(users);

  const groups = [];
  for (let i = 0; i < users.length; i += size) {
    groups.push(users.slice(i, i + size));
  }

  let sent = 0;
  let failed = 0;
  const perCard = cards.map((text) => ({
    text,
    groups: 0,
    sent: 0,
    failed: 0,
  }));
  const assignments = [];

  for (let g = 0; g < groups.length; g += 1) {
    const cardIndex = g % cards.length;
    const text = cards[cardIndex];
    for (const user of groups[g]) {
      assignments.push({ uid: user.uid, text, cardIndex });
    }
  }

  const dateKey = await persistDailyAngelCards({
    assignments,
    title: cleanTitle,
    adminUid,
  });

  for (let g = 0; g < groups.length; g += 1) {
    const cardIndex = g % cards.length;
    const body = cards[cardIndex];
    perCard[cardIndex].groups += 1;
    const chunk = groups[g];

    await Promise.all(
      chunk.map(async ({ uid, token }) => {
        const id = await sendNotification({
          token,
          title: cleanTitle,
          body,
          data: {
            type: 'angel_card',
            cardIndex: String(cardIndex),
            date: dateKey,
          },
          userId: uid,
        });
        if (id) {
          sent += 1;
          perCard[cardIndex].sent += 1;
        } else {
          failed += 1;
          perCard[cardIndex].failed += 1;
        }
      }),
    );
  }

  const db = getFirestore();
  if (db) {
    try {
      await db.collection('admin_angel_cards').add({
        title: cleanTitle,
        cards,
        groupSize: size,
        groupCount: groups.length,
        sent,
        failed,
        totalUsers,
        usersWithToken: users.length,
        perCard,
        publishedBy: adminUid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.warn('ANGEL CARD LOG SKIP:', err.message);
    }
  }

  return {
    sent,
    failed,
    totalUsers,
    usersWithToken: users.length,
    groupCount: groups.length,
    groupSize: size,
    cardCount: cards.length,
    dateKey,
    perCard,
  };
}

module.exports = {
  sendAngelCardNotifications,
  ALLOWED_GROUP_SIZES,
  MIN_CARDS,
  MAX_CARDS,
};
