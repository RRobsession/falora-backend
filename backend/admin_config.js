/** Firestore rules ve lib/config/admin_config.dart ile senkron tutun. */
const adminUids = ['DhBcumWgN0RLAHK8aSYb3S9jXEv1'];

function isAdminUid(uid) {
  return typeof uid === 'string' && adminUids.includes(uid);
}

module.exports = {
  adminUids,
  isAdminUid,
};
