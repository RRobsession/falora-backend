/// Admin paneline erişebilen Firebase Auth UID listesi.
/// Firestore rules ile senkron tutun (firestore.rules → isAdmin).
const adminUids = <String>[
  'DhBcumWgN0RLAHK8aSYb3S9jXEv1',
  'CV9g7RcjFbYu1wFYJJPNoCcxR3T2',
];

bool isAdminUser(String uid) => adminUids.contains(uid);
