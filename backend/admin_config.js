/** Firestore rules ve lib/config/admin_config.dart ile senkron tutun. */
const adminUids = [
  'l2vjDZXUbcOifjumq1q7HTubFxu2', // falora.admin@falora.app
  'o0AyRibzJFfNb6BNYxUweM4RqAs2', // henryarthur.rr@gmail.com
];

function isAdminUid(uid) {
  return typeof uid === 'string' && adminUids.includes(uid);
}

module.exports = {
  adminUids,
  isAdminUid,
};
