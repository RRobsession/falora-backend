/** Firestore rules ve lib/config/admin_config.dart ile senkron tutun. */
const adminUids = ['l2vjDZXUbcOifjumq1q7HTubFxu2'];

function isAdminUid(uid) {
  return typeof uid === 'string' && adminUids.includes(uid);
}

module.exports = {
  adminUids,
  isAdminUid,
};
