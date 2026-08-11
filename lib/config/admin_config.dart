/// Admin paneline erişebilen Firebase Auth UID listesi.
/// Firestore rules ile senkron tutun (firestore.rules → isAdmin).
import 'package:firebase_auth/firebase_auth.dart';

const adminUids = <String>[
  // falora.admin@falora.app
  'l2vjDZXUbcOifjumq1q7HTubFxu2',
  // henryarthur.rr@gmail.com
  'o0AyRibzJFfNb6BNYxUweM4RqAs2',
  // admin.35@tombikteyze.app
  'LmcMFwbp3eaLRrFRD2IURLW3reg1',
  // admin@tombikteyze.app
  'PcyiSwnAIWhkwlpsJ88fHYMFGJW2',
];

/// UID listesine ek güvenlik ağı.
const adminEmails = <String>[
  'falora.admin@falora.app',
  'henryarthur.rr@gmail.com',
  'admin.35@tombikteyze.app',
  'admin@tombikteyze.app',
];

bool isAdminUser(String uid, {String? email}) {
  if (adminUids.contains(uid)) return true;
  // Yalnızca Firebase Auth e-postası ile eşle (Firestore profili değil).
  final normalized = email?.trim().toLowerCase();
  if (normalized != null &&
      normalized.isNotEmpty &&
      adminEmails.contains(normalized)) {
    return true;
  }
  return false;
}

/// Admin yönlendirmesi için Firebase Auth oturumunu kullan.
bool isCurrentFirebaseUserAdmin() {
  final fbUser = FirebaseAuth.instance.currentUser;
  if (fbUser == null) return false;
  return isAdminUser(fbUser.uid, email: fbUser.email);
}
