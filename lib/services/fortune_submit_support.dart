import 'package:firebase_auth/firebase_auth.dart';
import 'package:falora/services/backend_auth_client.dart';
import 'package:falora/services/fortune_submit_logger.dart';
import 'package:falora/services/fortune_submit_messages.dart';
import 'package:falora/services/fortune_storage_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:flutter/foundation.dart';

class AuthRefreshResult {
  const AuthRefreshResult({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final bool emailVerified;
}

/// Fal gönderiminden hemen önce Firebase Auth oturumunu ve ID token'ı tazeler.
Future<AuthRefreshResult> refreshAuthBeforeSubmit() async {
  debugPrint('AUTH_REFRESH_BEFORE_SUBMIT_START');
  try {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('AUTH_REFRESH_BEFORE_SUBMIT_FAILED reason=current_user_null');
      throw FortuneSubmitException(fortuneSubmitSessionRefreshError);
    }

    await user.reload();
    debugPrint('AUTH_RELOAD_SUCCESS');

    user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint(
        'AUTH_REFRESH_BEFORE_SUBMIT_FAILED reason=current_user_null_after_reload',
      );
      throw FortuneSubmitException(fortuneSubmitSessionRefreshError);
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      debugPrint('AUTH_REFRESH_BEFORE_SUBMIT_FAILED reason=id_token_empty');
      throw FortuneSubmitException(fortuneSubmitSessionRefreshError);
    }
    debugPrint('AUTH_ID_TOKEN_FORCE_REFRESH_SUCCESS');

    final emailVerified = user.emailVerified;
    debugPrint('AUTH_AFTER_REFRESH_EMAIL_VERIFIED: $emailVerified');
    debugPrint('AUTH_AFTER_REFRESH_UID: ${user.uid}');
    debugPrint('AUTH_AFTER_REFRESH_EMAIL: ${user.email ?? '<null>'}');

    if (!emailVerified) {
      debugPrint('AUTH_REFRESH_BEFORE_SUBMIT_FAILED reason=email_not_verified');
      throw FortuneSubmitException(fortuneSubmitEmailNotVerifiedError);
    }

    return AuthRefreshResult(
      uid: user.uid,
      email: user.email ?? '',
      emailVerified: emailVerified,
    );
  } on FortuneSubmitException {
    rethrow;
  } catch (e, stackTrace) {
    debugPrint('AUTH_REFRESH_BEFORE_SUBMIT_FAILED error=$e');
    debugPrint(stackTrace.toString());
    throw FortuneSubmitException(fortuneSubmitSessionRefreshError);
  }
}

/// Fal gönderiminden önce kullanıcı dokümanı + oturum hazırlığı.
Future<int> prepareFortuneSubmit({
  required String uid,
  required String name,
  required String email,
  required int fortuneCost,
  required String logPrefix,
}) async {
  final auth = await refreshAuthBeforeSubmit();
  if (auth.uid != uid) {
    debugPrint(
      '$logPrefix AUTH_UID_MISMATCH expected=$uid actual=${auth.uid}',
    );
  }

  final hasToken = await FortuneSubmitLogger.authTokenExists();
  if (!hasToken) {
    debugPrint('AUTH_VERIFY_FAILED');
    debugPrint('FORTUNE_SUBMIT_FAILED_REASON auth_token_missing');
    throw FortuneSubmitException(fortuneSubmitAuthError);
  }
  debugPrint('AUTH_VERIFY_SUCCESS');

  await TokenService.instance.ensureUserDocument(
    uid: auth.uid,
    name: name,
    email: auth.email.isNotEmpty ? auth.email : email,
  );

  final balance = await TokenService.instance.readTokenBalance(auth.uid);
  debugPrint('USER_TOKEN_BALANCE_BEFORE: $balance');
  debugPrint('FORTUNE_COST: $fortuneCost');

  if (balance < fortuneCost) {
    debugPrint('FORTUNE_SUBMIT_FAILED_REASON insufficient_balance');
    throw FortuneSubmitException(fortuneSubmitInsufficientBalance);
  }

  return balance;
}

String mapFortuneSubmitError(
  Object error, {
  required String logPrefix,
  bool tokensDeducted = false,
  bool requestCreated = false,
}) {
  if (error is FortuneSubmitException) {
    debugPrint('FORTUNE_SUBMIT_FAILED_REASON ${error.message}');
    return error.message;
  }
  if (error is TokenSpendException) {
    debugPrint('FORTUNE_SUBMIT_FAILED_REASON ${error.code}');
    return error.userMessage;
  }
  if (error is BackendAuthException) {
    debugPrint('AUTH_VERIFY_FAILED');
    debugPrint('FORTUNE_SUBMIT_FAILED_REASON backend_auth');
    return fortuneSubmitAuthError;
  }
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      debugPrint('FIRESTORE_PERMISSION_DENIED');
      debugPrint('FORTUNE_SUBMIT_FAILED_REASON firestore_permission_denied');
      if (requestCreated && !tokensDeducted) {
        return fortuneSubmitPermissionError;
      }
      return fortuneSubmitUserDocError;
    }
    debugPrint('FORTUNE_SUBMIT_FAILED_REASON firestore_${error.code}');
    return fortuneSubmitServerError;
  }

  debugPrint('$logPrefix FORTUNE_SUBMIT_FAILED_REASON $error');
  return fortuneSubmitServerError;
}
