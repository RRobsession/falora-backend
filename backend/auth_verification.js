const admin = require('firebase-admin');
const { initFirebaseAdmin } = require('./fcm');
const { sendAuthEmail } = require('./resend_mail');
const {
  buildVerificationEmail,
  buildPasswordResetEmail,
} = require('./email_templates');

const CONTINUE_URL =
  process.env.FIREBASE_EMAIL_CONTINUE_URL ||
  process.env.FIREBASE_EMAIL_VERIFY_CONTINUE_URL ||
  'https://falora35.firebaseapp.com';

const PACKAGE_NAME =
  process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.rrlime.falora';

const IOS_BUNDLE_ID =
  process.env.FIREBASE_IOS_BUNDLE_ID || 'com.example.falora';

/** Basit bellek içi rate limit: email/ip başına. */
const rateBuckets = new Map();
const RATE_WINDOW_MS = 60 * 1000;
const RATE_MAX = 5;

function normalizeEmail(email) {
  if (typeof email !== 'string') return '';
  return email.trim().toLowerCase();
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function assertFirebaseReady() {
  if (!initFirebaseAdmin()) {
    const error = new Error(
      'Firebase Admin yapılandırılmadı. FIREBASE_SERVICE_ACCOUNT_JSON gerekli.',
    );
    error.statusCode = 503;
    error.code = 'firebase_not_configured';
    throw error;
  }
}

function buildActionCodeSettings() {
  return {
    url: CONTINUE_URL,
    handleCodeInApp: true,
    android: {
      packageName: PACKAGE_NAME,
      installApp: true,
      minimumVersion: '1',
    },
    iOS: {
      bundleId: IOS_BUNDLE_ID,
    },
  };
}

function checkRateLimit(key) {
  const now = Date.now();
  const entry = rateBuckets.get(key);
  if (!entry || now - entry.startedAt > RATE_WINDOW_MS) {
    rateBuckets.set(key, { startedAt: now, count: 1 });
    return;
  }
  entry.count += 1;
  if (entry.count > RATE_MAX) {
    const error = new Error('Çok fazla istek. Lütfen biraz sonra tekrar deneyin.');
    error.statusCode = 429;
    error.code = 'rate_limited';
    throw error;
  }
}

/**
 * Oturum açmış kullanıcıya doğrulama e-postası (Resend).
 * @param {{ uid: string, emailVerified?: boolean }} auth
 */
async function sendVerificationEmailForAuthUser(auth) {
  assertFirebaseReady();

  if (auth?.emailVerified) {
    return { ok: true, alreadyVerified: true };
  }

  const uid = auth?.uid;
  if (!uid) {
    const error = new Error('Kimlik doğrulama gerekli.');
    error.statusCode = 401;
    throw error;
  }

  checkRateLimit(`verify:${uid}`);

  let user;
  try {
    user = await admin.auth().getUser(uid);
  } catch (error) {
    console.error('AUTH VERIFY getUser failed:', error.message);
    const wrapped = new Error('Kullanıcı bulunamadı.');
    wrapped.statusCode = 404;
    throw wrapped;
  }

  const email = normalizeEmail(user.email || '');
  if (!email) {
    const error = new Error('Hesaba bağlı e-posta adresi yok.');
    error.statusCode = 400;
    throw error;
  }

  if (user.emailVerified) {
    return { ok: true, alreadyVerified: true };
  }

  let link;
  try {
    link = await admin
      .auth()
      .generateEmailVerificationLink(email, buildActionCodeSettings());
  } catch (error) {
    console.error(
      'generateEmailVerificationLink failed:',
      error.code || '',
      error.message,
    );
    const raw = String(error.message || '');
    let detail = 'Doğrulama bağlantısı oluşturulamadı.';
    if (raw.includes('TOO_MANY_ATTEMPTS_TRY_LATER')) {
      detail =
        'Çok fazla doğrulama denemesi yapıldı. Lütfen 15–30 dakika sonra tekrar deneyin.';
    } else if (error.code) {
      detail = `Doğrulama bağlantısı oluşturulamadı (${error.code}).`;
    }
    const wrapped = new Error(detail);
    wrapped.statusCode = raw.includes('TOO_MANY_ATTEMPTS') ? 429 : 500;
    throw wrapped;
  }

  const template = buildVerificationEmail({ link, email });
  try {
    const result = await sendAuthEmail({
      to: email,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
    console.log(
      `AUTH VERIFY EMAIL OK uid=${uid} resendId=${result?.id || 'n/a'}`,
    );
    return { ok: true, alreadyVerified: false, email };
  } catch (error) {
    console.error('AUTH VERIFY Resend failed:', error.message);
    const isConfig = error.code === 'resend_not_configured';
    const wrapped = new Error(
      isConfig
        ? 'E-posta servisi yapılandırılmamış.'
        : error.message || 'Doğrulama e-postası gönderilemedi.',
    );
    wrapped.statusCode = isConfig ? 503 : 502;
    wrapped.code = error.code || 'resend_send_failed';
    throw wrapped;
  }
}

/**
 * Şifre sıfırlama e-postası (oturum gerekmez). Enumeration korumalı.
 * @param {{ email: string, clientKey?: string }} params
 */
async function sendPasswordResetEmailForAddress({ email, clientKey }) {
  assertFirebaseReady();

  const normalized = normalizeEmail(email);
  if (!isValidEmail(normalized)) {
    const error = new Error('Geçerli bir e-posta girin.');
    error.statusCode = 400;
    throw error;
  }

  checkRateLimit(`reset:${clientKey || normalized}`);

  let userExists = true;
  try {
    await admin.auth().getUserByEmail(normalized);
  } catch (error) {
    if (error?.code === 'auth/user-not-found') {
      userExists = false;
    } else {
      console.error('AUTH RESET getUserByEmail failed:', error.message);
      const wrapped = new Error('Şifre sıfırlama başlatılamadı.');
      wrapped.statusCode = 500;
      throw wrapped;
    }
  }

  // Enumeration önleme: yoksa da başarılı dön.
  if (!userExists) {
    console.log('AUTH RESET silent miss');
    return { ok: true };
  }

  let link;
  try {
    link = await admin
      .auth()
      .generatePasswordResetLink(normalized, buildActionCodeSettings());
  } catch (error) {
    console.error('generatePasswordResetLink failed:', error.message);
    const wrapped = new Error('Şifre sıfırlama bağlantısı oluşturulamadı.');
    wrapped.statusCode = 500;
    throw wrapped;
  }

  const template = buildPasswordResetEmail({ link, email: normalized });
  try {
    const result = await sendAuthEmail({
      to: normalized,
      subject: template.subject,
      html: template.html,
      text: template.text,
    });
    console.log(`AUTH RESET EMAIL OK resendId=${result?.id || 'n/a'}`);
    return { ok: true };
  } catch (error) {
    console.error('AUTH RESET Resend failed:', error.message);
    const isConfig = error.code === 'resend_not_configured';
    const wrapped = new Error(
      isConfig
        ? 'E-posta servisi yapılandırılmamış.'
        : error.message || 'Şifre sıfırlama e-postası gönderilemedi.',
    );
    wrapped.statusCode = isConfig ? 503 : 502;
    wrapped.code = error.code || 'resend_send_failed';
    throw wrapped;
  }
}

module.exports = {
  sendVerificationEmailForAuthUser,
  sendPasswordResetEmailForAddress,
};
