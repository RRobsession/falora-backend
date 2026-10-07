/** Admin tarafından gönderilen, kullanıcı gruplarına özel Şans Kurabiyesi. */
const admin = require('firebase-admin');
const { getFirestore, isFcmReady, sendNotification } = require('./fcm');
const { isAdminUser } = require('./admin_config');

const ALLOWED_GROUP_SIZES = [10, 20];
const MIN_MESSAGES = 2;
const MAX_MESSAGES = 50;
const MIN_MESSAGE_LEN = 15;
const MAX_MESSAGE_LEN = 240;

function currentRef(uid) {
  return getFirestore()
    .collection('users')
    .doc(uid)
    .collection('fortune_cookies')
    .doc('current');
}

function normalizeMessages(input) {
  if (!Array.isArray(input)) {
    const error = new Error('Fal cümleleri gerekli.');
    error.code = 'invalid_messages';
    throw error;
  }
  const messages = input
    .map((value) => (typeof value === 'string' ? value.trim() : ''))
    .filter(Boolean);
  if (messages.length < MIN_MESSAGES || messages.length > MAX_MESSAGES) {
    const error = new Error(
      `En az ${MIN_MESSAGES}, en fazla ${MAX_MESSAGES} cümle girin.`,
    );
    error.code = 'invalid_message_count';
    throw error;
  }
  for (const message of messages) {
    if (message.length < MIN_MESSAGE_LEN || message.length > MAX_MESSAGE_LEN) {
      const error = new Error(
        `Her cümle ${MIN_MESSAGE_LEN}-${MAX_MESSAGE_LEN} karakter olmalı.`,
      );
      error.code = 'invalid_message_length';
      throw error;
    }
  }
  return messages;
}

function shuffleInPlace(items) {
  for (let i = items.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [items[i], items[j]] = [items[j], items[i]];
  }
  return items;
}

async function status(uid) {
  const db = getFirestore();
  if (!db) throw new Error('Firestore hazır değil');
  const snap = await currentRef(uid).get();
  const data = snap.data() || {};
  return {
    available:
      snap.exists && data.opened !== true && data.dismissed !== true,
    campaignId: data.campaignId || null,
  };
}

async function act(uid, action) {
  const db = getFirestore();
  if (!db) throw new Error('Firestore hazır değil');
  const ref = currentRef(uid);
  let fortune = null;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() || {};
    if (!snap.exists || data.opened === true || data.dismissed === true) {
      const error = new Error('Bu şans kurabiyesi daha önce kullanıldı.');
      error.code = 'already_used';
      throw error;
    }
    if (action === 'break') {
      fortune = String(data.fortune || '').trim();
      tx.set(ref, {
        opened: true,
        openedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } else {
      tx.set(ref, {
        dismissed: true,
        dismissedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  });
  return { success: true, fortune };
}

async function sendCampaign({ messages: input, groupSize, adminUid }) {
  if (!isFcmReady()) {
    const error = new Error('FCM yapılandırılmamış.');
    error.code = 'fcm_not_configured';
    throw error;
  }
  const messages = normalizeMessages(input);
  const size = Number(groupSize);
  if (!ALLOWED_GROUP_SIZES.includes(size)) {
    const error = new Error('Grup boyutu 10 veya 20 olmalı.');
    error.code = 'invalid_group_size';
    throw error;
  }

  const db = getFirestore();
  const usersSnap = await db.collection('users').get();
  const users = [];
  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    if (isAdminUser(doc.id, data.email)) continue;
    const token = data.fcmToken;
    // Push izni/tokeni olmayan kullanicilar da uygulamaya girdiklerinde
    // kurabiyeyi gorebilmeli. Token yalnizca push gonderimi icin gereklidir.
    users.push({
      uid: doc.id,
      token: typeof token === 'string' ? token.trim() : '',
    });
  }
  shuffleInPlace(users);

  const campaignRef = db.collection('admin_fortune_cookies').doc();
  const campaignId = campaignRef.id;
  const assignments = users.map((user, index) => ({
    ...user,
    messageIndex: Math.floor(index / size) % messages.length,
  }));

  for (let i = 0; i < assignments.length; i += 400) {
    const batch = db.batch();
    for (const assignment of assignments.slice(i, i + 400)) {
      batch.set(currentRef(assignment.uid), {
        campaignId,
        fortune: messages[assignment.messageIndex],
        messageIndex: assignment.messageIndex,
        opened: false,
        dismissed: false,
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  let sent = 0;
  let failed = 0;
  const pushAssignments = assignments.filter(({ token }) => token);
  for (let i = 0; i < pushAssignments.length; i += 100) {
    await Promise.all(
      pushAssignments.slice(i, i + 100).map(async ({ uid, token }) => {
        const id = await sendNotification({
          token,
          userId: uid,
          title: 'Şans kurabiyen geldi! 🥠',
          body: 'Hemen şans kurabiyeni kır ve falına bak.',
          data: { type: 'fortune_cookie', campaignId },
        });
        if (id) sent += 1;
        else failed += 1;
      }),
    );
  }

  const groupCount = Math.ceil(users.length / size);
  await campaignRef.set({
    messages,
    groupSize: size,
    groupCount,
    sent,
    failed,
    totalUsers: usersSnap.size,
    usersWithToken: pushAssignments.length,
    publishedBy: adminUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {
    success: true,
    campaignId,
    sent,
    failed,
    groupCount,
    totalUsers: usersSnap.size,
    usersWithToken: pushAssignments.length,
    assigned: assignments.length,
  };
}

module.exports = {
  status,
  act,
  sendCampaign,
  ALLOWED_GROUP_SIZES,
  MIN_MESSAGES,
  MAX_MESSAGES,
};
