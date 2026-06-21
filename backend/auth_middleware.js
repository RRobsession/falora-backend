const admin = require('firebase-admin');
const { initFirebaseAdmin } = require('./fcm');

/**
 * Firebase ID token doğrulaması — Authorization: Bearer <token>
 */
async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return res.status(401).json({ error: 'Kimlik doğrulama gerekli' });
  }

  if (!initFirebaseAdmin()) {
    return res.status(503).json({ error: 'Kimlik doğrulama servisi yapılandırılmadı' });
  }

  try {
    const decoded = await admin.auth().verifyIdToken(match[1]);
    req.auth = {
      uid: decoded.uid,
      email: typeof decoded.email === 'string' ? decoded.email : '',
      emailVerified: decoded.email_verified === true,
    };
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Geçersiz veya süresi dolmuş oturum' });
  }
}

function requireVerifiedEmail(req, res, next) {
  if (!req.auth?.emailVerified) {
    return res.status(403).json({ error: 'E-posta doğrulaması gerekli' });
  }
  return next();
}

/** Body'deki userId yalnızca oturum sahibine ait olabilir. */
function requireMatchingUserId(req, res, next) {
  const { userId } = req.body ?? {};
  if (!userId) {
    return res.status(400).json({ error: 'userId gerekli' });
  }
  if (userId !== req.auth.uid) {
    return res.status(403).json({ error: 'Yetkisiz işlem' });
  }
  return next();
}

module.exports = {
  requireAuth,
  requireVerifiedEmail,
  requireMatchingUserId,
};
