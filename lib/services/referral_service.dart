import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/config/app_links_config.dart';
import 'package:falora/config/referral_config.dart';
import 'package:falora/services/token_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

enum ReferralShareOutcome {
  nativeShare,
  webShare,
  clipboardFallback,
  dismissed,
  failed,
}

class ReferralException implements Exception {
  ReferralException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReferralService {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _random = Random.secure();

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateCode() {
    return List.generate(
      referralCodeLength,
      (_) => _codeChars[_random.nextInt(_codeChars.length)],
    ).join();
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _creditsRef(String inviterUid) =>
      _userRef(inviterUid).collection('referral_credits');

  Future<String> ensureReferralCode(String userId) async {
    debugPrint('REFERRAL_CODE_CREATE_START uid=$userId');
    final snap = await _userRef(userId).get();
    final existing = snap.data()?['referralCode'] as String?;
    if (existing != null && existing.trim().isNotEmpty) {
      debugPrint('REFERRAL_CODE_CREATE_SUCCESS existing=$existing');
      return existing.trim().toUpperCase();
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _generateCode();
      final codeRef = _db.collection('referral_codes').doc(code);
      try {
        await _db.runTransaction((tx) async {
          final codeSnap = await tx.get(codeRef);
          if (codeSnap.exists) {
            throw ReferralException('Kod çakışması');
          }
          tx.set(codeRef, {
            'uid': userId,
            'code': code,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(
            _userRef(userId),
            {'referralCode': code},
            SetOptions(merge: true),
          );
        });
        debugPrint('REFERRAL_CODE_CREATE_SUCCESS code=$code');
        return code;
      } on ReferralException {
        continue;
      }
    }
    debugPrint('REFERRAL_ERROR: referral code create failed');
    throw ReferralException('Davet kodu oluşturulamadı.');
  }

  Future<String?> resolveInviterUid(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final snap = await _db.collection('referral_codes').doc(code).get();
    if (!snap.exists) return null;
    return snap.data()?['uid'] as String?;
  }

  Future<void> applyReferralOnRegister({
    required String newUserId,
    required String? referralCode,
  }) async {
    if (referralCode == null || referralCode.trim().isEmpty) return;

    debugPrint('REFERRAL_APPLY_START newUser=$newUserId');
    final inviterUid = await resolveInviterUid(referralCode);
    if (inviterUid == null || inviterUid.isEmpty) {
      debugPrint('REFERRAL_ERROR: invalid code');
      throw ReferralException('Geçersiz davet kodu.');
    }
    if (inviterUid == newUserId) {
      debugPrint('REFERRAL_ERROR: self referral');
      throw ReferralException('Kendi davet kodunu kullanamazsın.');
    }

    await _userRef(newUserId).set(
      {'referredBy': inviterUid},
      SetOptions(merge: true),
    );
    debugPrint('REFERRAL_APPLY_SUCCESS inviter=$inviterUid');
  }

  Future<void> tryGrantReferralRewards(String userId) async {
    final snap = await _userRef(userId).get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final referredBy = data['referredBy'] as String?;
    final claimed = data['referralRewardClaimed'] as bool? ?? false;
    if (referredBy == null || referredBy.isEmpty || claimed) return;

    try {
      await _db.runTransaction((tx) async {
        final userSnap = await tx.get(_userRef(userId));
        if (!userSnap.exists) return;
        final userData = userSnap.data()!;
        if (userData['referralRewardClaimed'] == true) return;
        final inviter = userData['referredBy'] as String?;
        if (inviter == null || inviter.isEmpty || inviter == userId) return;

        final tokens = (userData['tokens'] as num?)?.toInt() ?? 0;
        tx.update(_userRef(userId), {
          'referralRewardClaimed': true,
          'tokens': tokens + referralInviteeRewardTokens,
        });

        final creditRef = _creditsRef(inviter).doc(userId);
        tx.set(creditRef, {
          'fromUid': userId,
          'amount': referralInviterRewardTokens,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      await TokenService.instance.fetchUser(userId);
      debugPrint('REFERRAL_REWARD_GRANTED invitee=$userId');
    } catch (e, stack) {
      debugPrint('REFERRAL_ERROR grant invitee: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> claimPendingInviterCredits(String inviterUid) async {
    final credits = await _creditsRef(inviterUid).get();
    if (credits.docs.isEmpty) return;

    for (final doc in credits.docs) {
      try {
        await _db.runTransaction((tx) async {
          final creditSnap = await tx.get(doc.reference);
          if (!creditSnap.exists) return;

          final userSnap = await tx.get(_userRef(inviterUid));
          if (!userSnap.exists) return;

          final amount =
              (creditSnap.data()?['amount'] as num?)?.toInt() ??
              referralInviterRewardTokens;
          final tokens = (userSnap.data()?['tokens'] as num?)?.toInt() ?? 0;
          tx.update(_userRef(inviterUid), {'tokens': tokens + amount});
          tx.delete(doc.reference);
        });
        debugPrint('REFERRAL_REWARD_GRANTED inviter=$inviterUid credit=${doc.id}');
      } catch (e) {
        debugPrint('REFERRAL_ERROR claim credit: $e');
      }
    }
  }

  String buildShareMessage(String code) {
    final buffer = StringBuffer("Falora'ya katıl!\nDavet kodum: $code");
    if (playStoreUrl.trim().isNotEmpty) {
      buffer.write('\n\n$playStoreUrl');
    }
    return buffer.toString();
  }

  Future<void> copyReferralCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
  }

  Future<ReferralShareOutcome> shareReferralCode(
    String code, {
    Rect? sharePositionOrigin,
  }) async {
    debugPrint('REFERRAL_SHARE_NATIVE_START code=$code');
    final message = buildShareMessage(code);

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: "Falora'ya katıl!",
          title: "Falora'ya katıl!",
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        debugPrint('REFERRAL_SHARE_NATIVE_SUCCESS dismissed');
        return ReferralShareOutcome.dismissed;
      }

      if (result.status == ShareResultStatus.success) {
        debugPrint('REFERRAL_SHARE_NATIVE_SUCCESS native');
        return ReferralShareOutcome.nativeShare;
      }

      // Web Share API başarılı olunca share_plus unavailable dönebilir.
      if (kIsWeb) {
        debugPrint('REFERRAL_SHARE_NATIVE_SUCCESS web');
        return ReferralShareOutcome.webShare;
      }

      debugPrint('REFERRAL_SHARE_NATIVE_ERROR status=${result.status}');
      return ReferralShareOutcome.failed;
    } catch (e, stack) {
      debugPrint('REFERRAL_SHARE_NATIVE_ERROR: $e');
      debugPrint(stack.toString());

      if (kIsWeb) {
        try {
          await Clipboard.setData(ClipboardData(text: message));
          debugPrint('REFERRAL_SHARE_NATIVE_SUCCESS clipboard');
          return ReferralShareOutcome.clipboardFallback;
        } catch (clipError) {
          debugPrint('REFERRAL_SHARE_NATIVE_ERROR clipboard: $clipError');
          return ReferralShareOutcome.failed;
        }
      }

      return ReferralShareOutcome.failed;
    }
  }
}
