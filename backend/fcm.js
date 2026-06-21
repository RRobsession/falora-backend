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
const FCM_ANDROID_CHANNEL_ID =
  process.env.FCM_ANDROID_CHANNEL_ID || 'falora_notifications';
const MAX_TIMEOUT_MS = 2147483647;

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

async function notifyFortuneReady(userId, type) {
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

  const messageId = await sendNotification({
    token,
    title: template.title,
    body: template.body,
    data: { type, userId },
    userId,
  });

  if (messageId == null) {
    return { success: false, reason: 'send_failed' };
  }

  return { success: true, messageId };
}

function scheduleFortuneNotify(userId, type, notifyAtIso, readingId) {
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

  const delayMs = Math.max(0, notifyAt - Date.now());
  const key = readingId || `${userId}:${type}:${notifyAtIso}`;

  const existing = scheduledJobs.get(key);
  if (existing) {
    clearTimeout(existing);
  }

  console.log(
    'FCM SCHEDULE START | userId=',
    userId,
    '| type=',
    type,
    '| readingId=',
    readingId || '-',
    '| delayMs=',
    delayMs,
  );

  const cappedDelay = Math.min(delayMs, MAX_TIMEOUT_MS);
  const timer = setTimeout(async () => {
    scheduledJobs.delete(key);
    console.log(
      'FCM SCHEDULE FIRE | userId=',
      userId,
      '| type=',
      type,
      '| readingId=',
      readingId || '-',
    );
    await notifyFortuneReady(userId, type);
  }, cappedDelay);

  scheduledJobs.set(key, timer);

  return {
    success: true,
    scheduledInMs: delayMs,
    readingId: readingId || null,
  };
}

module.exports = {
  initFirebaseAdmin,
  isFcmReady,
  getFirestore,
  getUserFcmToken,
  sendNotification,
  notifyFortuneReady,
  scheduleFortuneNotify,
  READY_MESSAGES,
  FCM_ANDROID_CHANNEL_ID,
};
