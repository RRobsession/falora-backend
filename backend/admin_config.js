/** Firestore rules ve lib/config/admin_config.dart ile senkron tutun. */
const adminUids = [
  'l2vjDZXUbcOifjumq1q7HTubFxu2', // falora.admin@falora.app
  'o0AyRibzJFfNb6BNYxUweM4RqAs2', // henryarthur.rr@gmail.com
  'LmcMFwbp3eaLRrFRD2IURLW3reg1', // admin.35@tombikteyze.app
  'PcyiSwnAIWhkwlpsJ88fHYMFGJW2', // admin@tombikteyze.app
];

const adminEmails = [
  'falora.admin@falora.app',
  'henryarthur.rr@gmail.com',
  'admin.35@tombikteyze.app',
  'admin@tombikteyze.app',
];

function isAdminUid(uid) {
  return typeof uid === 'string' && adminUids.includes(uid);
}

function isAdminEmail(email) {
  if (typeof email !== 'string') return false;
  const normalized = email.trim().toLowerCase();
  return normalized.length > 0 && adminEmails.includes(normalized);
}

function isAdminUser(uid, email) {
  return isAdminUid(uid) || isAdminEmail(email);
}

module.exports = {
  adminUids,
  adminEmails,
  isAdminUid,
  isAdminEmail,
  isAdminUser,
};
