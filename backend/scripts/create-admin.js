/**
 * Tek seferlik admin hesabı oluşturur.
 * Kullanım: node scripts/create-admin.js
 */
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');

const SERVICE_ACCOUNT_PATH = path.join(
  __dirname,
  '..',
  'firebase-service-account.json',
);

const ADMIN_EMAIL = 'falora.admin@falora.app';
const ADMIN_NAME = 'Falora Admin';

function generatePassword() {
  const base = crypto.randomBytes(12).toString('base64url');
  return `Fa!${base}9`;
}

async function main() {
  if (!admin.apps.length) {
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const auth = admin.auth();
  const db = admin.firestore();
  const password = generatePassword();

  let user;
  try {
    user = await auth.getUserByEmail(ADMIN_EMAIL);
    console.log('Mevcut admin kullanıcısı bulundu, şifre güncelleniyor...');
    await auth.updateUser(user.uid, {
      password,
      emailVerified: true,
      displayName: ADMIN_NAME,
    });
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    user = await auth.createUser({
      email: ADMIN_EMAIL,
      password,
      emailVerified: true,
      displayName: ADMIN_NAME,
    });
  }

  await db.collection('users').doc(user.uid).set(
    {
      uid: user.uid,
      name: ADMIN_NAME,
      email: ADMIN_EMAIL,
      tokens: 50,
      rewardedAdsToday: 0,
      emailVerified: true,
      emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log('\n=== FALORA ADMIN HESABI ===');
  console.log('E-posta:', ADMIN_EMAIL);
  console.log('Şifre:', password);
  console.log('UID:', user.uid);
  console.log('===========================\n');
  console.log(
    'Bu bilgileri güvenli saklayın. admin_config.dart ve firestore.rules güncellenecek.',
  );
}

main().catch((err) => {
  console.error('Admin oluşturulamadı:', err.message);
  process.exit(1);
});
