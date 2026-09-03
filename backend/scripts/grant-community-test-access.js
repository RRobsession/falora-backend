const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
const admin = require('firebase-admin');
const { initFirebaseAdmin, getFirestore } = require('../fcm');

async function main() {
  const email = String(process.argv[2] || '').trim().toLowerCase();
  const days = Math.min(90, Math.max(1, Number(process.argv[3]) || 30));
  if (!email.includes('@')) throw new Error('E-posta parametresi gerekli.');
  if (!initFirebaseAdmin()) throw new Error('Firebase Admin başlatılamadı.');
  const user = await admin.auth().getUserByEmail(email);
  await getFirestore().collection('community_entitlements').doc(user.uid).set({
    uid: user.uid,
    productId: 'admin_test_access',
    status: 'active',
    source: 'local_admin_script',
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + days * 86400000),
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`Fal Meclisi test üyeliği verildi: ${email}, ${days} gün, uid=${user.uid}`);
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
