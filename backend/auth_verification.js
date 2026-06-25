const FIREBASE_WEB_API_KEY =
  process.env.FIREBASE_WEB_API_KEY || 'AIzaSyCoEZyfII5OgKEWbx5zMNhOJso-z7uQMNk';

const VERIFY_CONTINUE_URL =
  process.env.FIREBASE_EMAIL_VERIFY_CONTINUE_URL ||
  'https://falora35.firebaseapp.com';

/**
 * Firebase Identity Toolkit üzerinden doğrulama e-postası gönderir.
 * İstemci sendEmailVerification başarısız olduğunda yedek kanal.
 */
async function sendVerificationEmailWithIdToken(idToken) {
  if (!idToken || typeof idToken !== 'string') {
    return { ok: false, reason: 'missing_id_token' };
  }

  const url = `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${FIREBASE_WEB_API_KEY}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      requestType: 'VERIFY_EMAIL',
      idToken: idToken.trim(),
      continueUrl: VERIFY_CONTINUE_URL,
    }),
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      body?.error?.message || `HTTP ${response.status}`;
    console.error('AUTH VERIFY EMAIL FAILED:', message);
    return { ok: false, reason: message };
  }

  console.log('AUTH VERIFY EMAIL OK');
  return { ok: true, email: body.email || null };
}

module.exports = {
  sendVerificationEmailWithIdToken,
};
