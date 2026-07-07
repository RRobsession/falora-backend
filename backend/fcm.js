const path = require('path');
const admin = require('firebase-admin');
const {
  loadServiceAccount,
  describeServiceAccountEnv,
} = require('./service_account_config');

const BACKEND_DIR = __dirname;
const DEFAULT_SERVICE_ACCOUNT_PATH = path.join(
  BACKEND_DIR,
  'firebase-service-account.json',
);
const { safeLog } = require('./safe_log');
const { adminUids } = require('./admin_config');
const FCM_ANDROID_CHANNEL_ID =
  process.env.FCM_ANDROID_CHANNEL_ID || 'falora_ready';
const MAX_TIMEOUT_MS = 2147483647;
const NOTIFICATION_SCHEDULES = 'notification_schedules';

let messaging = null;
let firestore = null;
let initAttempted = false;
const scheduledJobs = new Map();

const READY_MESSAGES = {
  fortune: {
    title: 'Falın hazır!',
    body: 'Yorumun hazır, şimdi görüntüleyebilirsin.',
  },
  couple: {
    title: 'Çift uyumu raporun hazır!',
    body: 'Uyum raporun hazır, şimdi inceleyebilirsin.',
  },
  manual: {
    title: 'Özel fal yorumun hazır.',
    body: 'Özel fal yorumun hazır, şimdi görüntüleyebilirsin.',
  },
};

function resolveServiceAccount() {
  const loaded = loadServiceAccount({
    label: 'Firebase Admin',
    jsonEnv: 'FIREBASE_SERVICE_ACCOUNT_JSON',
    pathEnv: 'FIREBASE_SERVICE_ACCOUNT_PATH',
    defaultPath: DEFAULT_SERVICE_ACCOUNT_PATH,
  });
  return loaded?.credentials ?? null;
}

function logFirebaseAdminConfigStatus() {
  const status = describeServiceAccountEnv(
    'FIREBASE_SERVICE_ACCOUNT_JSON',
    'FIREBASE_SERVICE_ACCOUNT_PATH',
  );
  console.error('Firebase Admin yapılandırılmadı.', {
    hasJsonEnv: status.hasJsonEnv,
    hasPathEnv: status.hasPathEnv,
    pathFileExists: status.pathExists,
    hint: status.hasJsonEnv
      ? 'FIREBASE_SERVICE_ACCOUNT_JSON parse edilemedi; JSON ve private_key \\n formatını kontrol edin.'
      : 'Railway Variables içine FIREBASE_SERVICE_ACCOUNT_JSON ekleyin (tek satır JSON).',
  });
}

function initFirebaseAdmin() {
  if (messaging) return true;
  if (initAttempted && !messaging) return false;

  initAttempted = true;

  try {
    const serviceAccount = resolveServiceAccount();
    if (!serviceAccount) {
      logFirebaseAdminConfigStatus();
      return false;
    }

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }

    messaging = admin.messaging();
    firestore = admin.firestore();
    console.log(
      'Firebase Admin SDK hazır | projectId=',
      serviceAccount.project_id,
    );
    void restorePendingNotificationSchedules().catch((err) => {
      console.error('FCM SCHEDULE RESTORE ERROR:', err.message);
    });
    return true;
  } catch (err) {
    console.error('Firebase Admin başlatılamadı:', err.message);
    logFirebaseAdminConfigStatus();
    return false;
  }
}

function isFcmReady() {
  if (messaging) return true;
  return initFirebaseAdmin();
}

function getFirestore() {
  if (firestore) return firestore;
  if (!initFirebaseAdmin()) return null;
  return firestore;
}

async function getUserFcmToken(userId) {
  if (!isFcmReady()) {
    safeLog('FCM TOKEN NOT FOUND | reason=not_configured');
    return null;
  }

  const doc = await firestore.collection('users').doc(userId).get();
  if (!doc.exists) {
    safeLog('FCM TOKEN NOT FOUND | reason=user_missing');
    return null;
  }

  const token = doc.data()?.fcmToken;
  if (typeof token === 'string' && token.trim()) {
    safeLog('FCM TOKEN FOUND');
    return token.trim();
  }

  safeLog('FCM TOKEN NOT FOUND | reason=empty_field');
  return null;
}

async function clearUserFcmToken(userId) {
  if (!isFcmReady()) return;
  try {
    await firestore.collection('users').doc(userId).update({
      fcmToken: admin.firestore.FieldValue.delete(),
    });
    safeLog('FCM: geçersiz token silindi');
  } catch (err) {
    console.warn('FCM: token silinemedi | userId=', userId, '|', err.message);
  }
}

async function sendNotification({ token, title, body, data = {}, userId }) {
  if (!isFcmReady()) {
    console.error(
      'FCM SEND ERROR | reason=firebase_admin_not_configured | FIREBASE_SERVICE_ACCOUNT_JSON gerekli',
    );
    return null;
  }

  safeLog('FCM SEND START | title=', title);

  const message = {
    token,
    notification: { title, body },
    data: {
      title,
      body,
      ...Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: FCM_ANDROID_CHANNEL_ID,
        priority: 'high',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  try {
    const messageId = await messaging.send(message);
    safeLog('FCM SEND SUCCESS | messageId=', messageId);
    return messageId;
  } catch (err) {
    console.error(
      'FCM SEND ERROR | code=',
      err.code || '-',
      '| message=',
      err.message,
      '| title=',
      title,
    );

    if (
      userId &&
      (err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token')
    ) {
      await clearUserFcmToken(userId);
    }

    return null;
  }
}

async function notifyFortuneReady(userId, type, readingId) {
  const template = READY_MESSAGES[type];
  if (!template) {
    const err = new Error('type fortune, couple veya manual olmalı');
    err.code = 'invalid_type';
    throw err;
  }

  if (!isFcmReady()) {
    console.log(
      'FCM SEND ERROR | reason=not_configured | userId=',
      userId,
      '| type=',
      type,
    );
    return { success: false, reason: 'fcm_not_configured' };
  }

  const token = await getUserFcmToken(userId);
  if (!token) {
    return { success: false, reason: 'no_token' };
  }

  const data = { type, userId };
  if (readingId) {
    data.readingId = String(readingId);
  }

  const messageId = await sendNotification({
    token,
    title: template.title,
    body: template.body,
    data,
    userId,
  });

  if (messageId == null) {
    return { success: false, reason: 'send_failed' };
  }

  return { success: true, messageId };
}

async function getAdminFcmTokens() {
  const tokens = [];
  for (const uid of adminUids) {
    const token = await getUserFcmToken(uid);
    if (token) {
      tokens.push({ uid, token });
    }
  }
  return tokens;
}

async function notifyAdminsNewManualRequest({
  requestId,
  readerName,
  categoryLabel,
  clientName,
}) {
  if (!isFcmReady()) {
    console.log(
      'FCM ADMIN NOTIFY | reason=not_configured | requestId=',
      requestId,
    );
    return { success: false, reason: 'fcm_not_configured' };
  }

  const admins = await getAdminFcmTokens();
  if (admins.length === 0) {
    safeLog('FCM ADMIN NOTIFY | reason=no_admin_tokens | requestId=', requestId);
    return { success: false, reason: 'no_admin_tokens' };
  }

  const reader = readerName?.trim() || 'Özel yorumcu';
  const category = categoryLabel?.trim() || 'Özel fal';
  const client = clientName?.trim();
  const title = 'Yeni özel fal talebi';
  const body = client
    ? `${reader} — ${category} (${client})`
    : `${reader} — ${category}`;

  let sent = 0;
  for (const { uid, token } of admins) {
    const messageId = await sendNotification({
      token,
      title,
      body,
      data: {
        type: 'admin_manual_request',
        requestId: String(requestId),
      },
      userId: uid,
    });
    if (messageId) sent += 1;
  }

  return {
    success: sent > 0,
    sent,
    total: admins.length,
  };
}

function scheduleInMemoryTimer(scheduleId, userId, type, notifyAtMs) {
  const delayMs = Math.max(0, notifyAtMs - Date.now());
  const existing = scheduledJobs.get(scheduleId);
  if (existing) {
    clearTimeout(existing);
  }

  console.log(
    'FCM SCHEDULE TIMER | scheduleId=',
    scheduleId,
    '| userId=',
    userId,
    '| type=',
    type,
    '| delayMs=',
    delayMs,
  );

  const cappedDelay = Math.min(delayMs, MAX_TIMEOUT_MS);
  const timer = setTimeout(() => {
    scheduledJobs.delete(scheduleId);
    void fireScheduledNotification(scheduleId, userId, type).catch((err) => {
      console.error(
        'FCM SCHEDULE FIRE ERROR | scheduleId=',
        scheduleId,
        '|',
        err.message,
      );
    });
  }, cappedDelay);

  scheduledJobs.set(scheduleId, timer);
  return delayMs;
}

async function isReadingReadyForNotification(type, readingId, notifyAtMs) {
  if (Date.now() < notifyAtMs) return false;

  const collection =
    type === 'couple'
      ? 'couple_compatibility_requests'
      : 'fortune_requests';
  const doc = await firestore.collection(collection).doc(readingId).get();
  if (!doc.exists) return false;

  const data = doc.data() || {};
  const result = typeof data.result === 'string' ? data.result.trim() : '';
  if (!result) return false;
  if (data.status === 'error') return false;
  return true;
}

async function fireScheduledNotification(scheduleId, userId, type) {
  if (!isFcmReady()) {
    return { success: false, reason: 'fcm_not_configured' };
  }

  const ref = firestore.collection(NOTIFICATION_SCHEDULES).doc(scheduleId);
  const snap = await ref.get();
  if (!snap.exists) {
    return { success: false, reason: 'missing_schedule' };
  }

  const data = snap.data() || {};
  if (data.sent === true) {
    return { success: false, reason: 'already_sent' };
  }

  const readingId = data.readingId || scheduleId;
  const notifyAtMs = data.notifyAt?.toDate?.()?.getTime?.() ?? Date.now();
  const ready = await isReadingReadyForNotification(type, readingId, notifyAtMs);

  if (!ready) {
    const giveUpAt = notifyAtMs + 30 * 60 * 1000;
    if (Date.now() >= giveUpAt) {
      await ref.set(
        { sent: true, skippedReason: 'result_timeout' },
        { merge: true },
      );
      return { success: false, reason: 'result_timeout' };
    }

    scheduleInMemoryTimer(scheduleId, userId, type, Date.now() + 20_000);
    return { success: false, reason: 'waiting_for_result' };
  }

  const shouldSend = await firestore.runTransaction(async (tx) => {
    const latest = await tx.get(ref);
    if (!latest.exists) return false;
    if (latest.data()?.sent === true) return false;
    tx.set(
      ref,
      {
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return true;
  });

  if (!shouldSend) {
    safeLog('FCM SCHEDULE SKIP | already sent or missing | scheduleId=', scheduleId);
    return { success: false, reason: 'already_sent' };
  }

  console.log(
    'FCM SCHEDULE FIRE | scheduleId=',
    scheduleId,
    '| userId=',
    userId,
    '| type=',
    type,
  );
  return notifyFortuneReady(userId, type, readingId);
}

async function restorePendingNotificationSchedules() {
  if (!isFcmReady()) return;

  const snap = await firestore
    .collection(NOTIFICATION_SCHEDULES)
    .where('sent', '==', false)
    .get();

  if (snap.empty) {
    console.log('FCM SCHEDULE RESTORE | pending=0');
    return;
  }

  console.log('FCM SCHEDULE RESTORE | pending=', snap.size);
  const now = Date.now();

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const userId = data.userId;
    const type = data.type;
    const notifyAt = data.notifyAt?.toDate?.();
    if (!userId || !type || !notifyAt) continue;

    if (notifyAt.getTime() <= now) {
      await fireScheduledNotification(doc.id, userId, type);
    } else {
      scheduleInMemoryTimer(doc.id, userId, type, notifyAt.getTime());
    }
  }
}

async function scheduleFortuneNotify(userId, type, notifyAtIso, readingId) {
  const template = READY_MESSAGES[type];
  if (!template) {
    const err = new Error('type fortune, couple veya manual olmalı');
    err.code = 'invalid_type';
    throw err;
  }

  if (!isFcmReady()) {
    console.log(
      'FCM SEND ERROR | reason=not_configured | schedule skipped | userId=',
      userId,
    );
    return { success: false, reason: 'fcm_not_configured' };
  }

  const notifyAt = new Date(notifyAtIso).getTime();
  if (Number.isNaN(notifyAt)) {
    const err = new Error('notifyAt geçerli ISO tarih olmalı');
    err.code = 'invalid_notify_at';
    throw err;
  }

  const scheduleId = readingId || `${userId}:${type}:${notifyAtIso}`;

  await firestore.collection(NOTIFICATION_SCHEDULES).doc(scheduleId).set(
    {
      userId,
      type,
      readingId: readingId || scheduleId,
      notifyAt: admin.firestore.Timestamp.fromMillis(notifyAt),
      sent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const delayMs = scheduleInMemoryTimer(scheduleId, userId, type, notifyAt);

  return {
    success: true,
    scheduledInMs: delayMs,
    readingId: readingId || null,
    scheduleId,
  };
}

module.exports = {
  initFirebaseAdmin,
  isFcmReady,
  getFirestore,
  getUserFcmToken,
  sendNotification,
  notifyFortuneReady,
  notifyAdminsNewManualRequest,
  scheduleFortuneNotify,
  restorePendingNotificationSchedules,
  READY_MESSAGES,
  FCM_ANDROID_CHANNEL_ID,
};
