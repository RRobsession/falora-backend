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
const NOTIFICATION_SCHEDULES = 'notification_schedules';
const NOTIFICATION_WORKER_INTERVAL_MS = 20 * 1000;
const PROBLEM_REPORTS = 'problem_reports';
const PROBLEM_REPORT_WORKER_INTERVAL_MS = 20 * 1000;

let messaging = null;
let firestore = null;
let initAttempted = false;
let notificationWorkerTimer = null;
let notificationWorkerInFlight = false;
let problemReportWorkerTimer = null;
let problemReportWorkerInFlight = false;

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
    startNotificationScheduleWorker();
    startProblemReportNotificationWorker();
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

async function notifyAdmins({ title, body, type, data = {} }) {
  if (!isFcmReady()) {
    return { success: false, reason: 'fcm_not_configured' };
  }

  const admins = await getAdminFcmTokens();
  if (admins.length === 0) {
    return { success: false, reason: 'no_admin_tokens' };
  }

  let sent = 0;
  for (const { uid, token } of admins) {
    const messageId = await sendNotification({
      token,
      title,
      body,
      data: { type, ...data },
      userId: uid,
    });
    if (messageId) sent += 1;
  }

  return { success: sent > 0, sent, total: admins.length };
}

async function notifyAdminsNewTokenPurchase({
  productId,
  tokensGranted,
  userEmail,
  orderId,
}) {
  const amount = Number(tokensGranted) || 0;
  const buyer = userEmail?.trim() || 'Bir kullanıcı';
  const packageLabel = amount > 0 ? `${amount} jeton` : productId;
  return notifyAdmins({
    title: 'Yeni jeton satın alımı',
    body: `${buyer} • ${packageLabel}${orderId ? ` • ${orderId}` : ''}`,
    type: 'admin_token_purchase',
    data: { productId: productId || '', orderId: orderId || '' },
  });
}

async function notifyAdminsNewProblemReport({ reportId, displayName }) {
  const reporter = displayName?.trim() || 'Bir kullanıcı';
  return notifyAdmins({
    title: 'Yeni sorun bildirimi',
    body: `${reporter} yeni bir sorun bildirdi.`,
    type: 'admin_problem_report',
    data: { requestId: String(reportId) },
  });
}

async function notifyUserSupportReply({ userId, reportId }) {
  const token = await getUserFcmToken(userId);
  if (!token) return { success: false, reason: 'no_token' };
  const messageId = await sendNotification({
    token,
    title: 'Destek ekibi yanıtladı',
    body: 'Açık destek görüşmene yeni bir mesaj geldi.',
    data: { type: 'support_admin_reply', reportId: String(reportId) },
    userId,
  });
  return messageId
    ? { success: true, sent: 1, messageId }
    : { success: false, reason: 'send_failed' };
}

async function notifyAdminsSupportReply({ reportId, displayName }) {
  const sender = displayName?.trim() || 'Bir kullanıcı';
  return notifyAdmins({
    title: 'Destek talebine yeni yanıt',
    body: `${sender} açık destek görüşmesine yanıt yazdı.`,
    type: 'admin_support_reply',
    data: { reportId: String(reportId), requestId: String(reportId) },
  });
}

async function notifyAdminsForProblemReport(reportId) {
  const ref = firestore.collection(PROBLEM_REPORTS).doc(reportId);
  const claimed = await firestore.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const data = snap.data() || {};
    if (data.status !== 'open' || data.adminNotified === true) return null;
    if (data.adminNotificationClaimed === true) return null;
    tx.set(
      ref,
      {
        adminNotificationClaimed: true,
        adminNotificationClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { displayName: data.displayName };
  });

  if (!claimed) return { success: false, reason: 'already_handled' };

  try {
    const result = await notifyAdminsNewProblemReport({
      reportId,
      displayName: claimed.displayName,
    });
    if (result.success) {
      await ref.set(
        {
          adminNotified: true,
          adminNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          adminNotificationSent: result.sent || 0,
        },
        { merge: true },
      );
      return result;
    }

    await ref.set(
      {
        adminNotificationClaimed: admin.firestore.FieldValue.delete(),
        adminNotificationLastError: result.reason || 'send_failed',
      },
      { merge: true },
    );
    return result;
  } catch (error) {
    await ref.set(
      {
        adminNotificationClaimed: admin.firestore.FieldValue.delete(),
        adminNotificationLastError: error.message || 'send_failed',
      },
      { merge: true },
    );
    throw error;
  }
}

async function processPendingProblemReportNotifications() {
  if (!isFcmReady() || problemReportWorkerInFlight) return;
  problemReportWorkerInFlight = true;
  try {
    const snap = await firestore
      .collection(PROBLEM_REPORTS)
      .where('status', '==', 'open')
      .limit(50)
      .get();
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (data.adminNotified === true || data.adminNotificationClaimed === true) {
        continue;
      }
      await notifyAdminsForProblemReport(doc.id);
    }
  } finally {
    problemReportWorkerInFlight = false;
  }
}

function startProblemReportNotificationWorker() {
  if (problemReportWorkerTimer) return problemReportWorkerTimer;
  void processPendingProblemReportNotifications().catch((error) => {
    console.error('FCM PROBLEM REPORT WORKER ERROR:', error.message);
  });
  problemReportWorkerTimer = setInterval(() => {
    void processPendingProblemReportNotifications().catch((error) => {
      console.error('FCM PROBLEM REPORT WORKER ERROR:', error.message);
    });
  }, PROBLEM_REPORT_WORKER_INTERVAL_MS);
  if (typeof problemReportWorkerTimer.unref === 'function') {
    problemReportWorkerTimer.unref();
  }
  return problemReportWorkerTimer;
}

async function notifyAdminsNewManualRequest({
  requestId,
  readerId,
  readerName,
  categoryLabel,
  clientName,
}) {
  if (readerId !== 'serdar' && readerId !== 'hatice') {
    return { success: false, reason: 'reader_not_notifiable' };
  }
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

async function isReadingReadyForNotification(type, readingId, notifyAtMs) {
  if (Date.now() < notifyAtMs) return false;

  if (type === 'manual') {
    const doc = await firestore
      .collection('manual_fortune_requests')
      .doc(readingId)
      .get();
    if (!doc.exists) return false;

    const data = doc.data() || {};
    const answerText =
      typeof data.answerText === 'string' ? data.answerText.trim() : '';
    if (!answerText) return false;
    if (data.status !== 'answered') return false;
    return true;
  }

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
  if (notificationWorkerInFlight) return;

  notificationWorkerInFlight = true;

  try {
    const snap = await firestore
      .collection(NOTIFICATION_SCHEDULES)
      .where('sent', '==', false)
      .get();

    if (snap.empty) return;

    const now = Date.now();
    let due = 0;

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const userId = data.userId;
      const type = data.type;
      const notifyAt = data.notifyAt?.toDate?.();
      if (!userId || !type || !notifyAt || notifyAt.getTime() > now) continue;

      due += 1;
      await fireScheduledNotification(doc.id, userId, type);
    }

    if (due > 0) {
      console.log('FCM SCHEDULE WORKER | pending=', snap.size, '| due=', due);
    }
  } finally {
    notificationWorkerInFlight = false;
  }
}

function startNotificationScheduleWorker() {
  if (notificationWorkerTimer) return notificationWorkerTimer;

  notificationWorkerTimer = setInterval(() => {
    void restorePendingNotificationSchedules().catch((err) => {
      console.error('FCM SCHEDULE WORKER ERROR:', err.message);
    });
  }, NOTIFICATION_WORKER_INTERVAL_MS);

  if (typeof notificationWorkerTimer.unref === 'function') {
    notificationWorkerTimer.unref();
  }

  return notificationWorkerTimer;
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

  return {
    success: true,
    scheduledInMs: Math.max(0, notifyAt - Date.now()),
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
  notifyAdminsNewTokenPurchase,
  notifyAdminsNewProblemReport,
  notifyUserSupportReply,
  notifyAdminsSupportReply,
  notifyAdminsForProblemReport,
  scheduleFortuneNotify,
  restorePendingNotificationSchedules,
  READY_MESSAGES,
  FCM_ANDROID_CHANNEL_ID,
};
