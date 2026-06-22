import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/config/app_branding.dart';
import 'package:falora/config/app_links_config.dart';
import 'package:falora/config/referral_config.dart';
import 'package:falora/services/referral_backend_service.dart';
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
  final Map<String, String> _pendingReferralCodesByUid = {};

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateCode() {
    return List.generate(
      referralCodeLength,
      (_) => _codeChars[_random.nextInt(_codeChars.length)],
    ).join();
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  void storePendingReferralCode(String uid, String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;
    debugPrint('REFERRAL_CODE_ENTERED uid=$uid code=$code');
    _pendingReferralCodesByUid[uid] = code;
  }

  String? peekPendingReferralCode(String uid) =>
      _pendingReferralCodesByUid[uid];

  String? takePendingReferralCode(String uid) =>
      _pendingReferralCodesByUid.remove(uid);

  /// E-posta doğrulandıktan sonra bekleyen referans kodunu backend üzerinden işler.
  /// Kullanıcıya gösterilecek mesaj varsa döner; hata kayıt akışını bozmaz.
  Future<String?> claimPendingReferralIfNeeded(String uid) async {
    final code = peekPendingReferralCode(uid);
    if (code == null || code.isEmpty) return null;

    try {
      final result = await ReferralBackendService.instance.claimReferral(
        referralCode: code,
      );

      takePendingReferralCode(uid);

      if (result.code == ReferralClaimCode.success && result.rewardTokens > 0) {
        final current = TokenService.instance.liveUser.value;
        if (current != null && current.userId == uid) {
          TokenService.instance.liveUser.value = current.copyWith(
            tokens: current.tokens + result.rewardTokens,
          );
        }
      }

      return switch (result.code) {
        ReferralClaimCode.success => referralSuccessInviteeMessage,
        ReferralClaimCode.notFound => referralCodeNotFoundMessage,
        ReferralClaimCode.selfReferral => null,
        ReferralClaimCode.alreadyClaimed => null,
        ReferralClaimCode.serverError => null,
      };
    } on ReferralBackendException catch (e) {
      debugPrint('REFERRAL_TRANSACTION_FAILED: ${e.message}');
      debugPrint('REFERRAL_IGNORED_REGISTRATION_CONTINUES');
      return null;
    } catch (e, stack) {
      debugPrint('REFERRAL_TRANSACTION_FAILED: $e');
      debugPrint(stack.toString());
      debugPrint('REFERRAL_IGNORED_REGISTRATION_CONTINUES');
      return null;
    }
  }

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

  String buildShareMessage(String code) {
    final buffer = StringBuffer(
      "$appDisplayName'ye katıl!\n"
      'Davet kodum: $code\n\n'
      'Kayıt olurken kodu gir; ikiniz de $referralInviterRewardTokens jeton kazanın.',
    );
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
          subject: "$appDisplayName'ye katıl!",
          title: "$appDisplayName'ye katıl!",
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
