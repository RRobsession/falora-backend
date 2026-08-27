import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/services/statistics_service.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/services/daily_horoscope_service.dart';
import 'package:falora/services/fortune_submit_messages.dart';
import 'package:falora/token_config.dart';
import 'package:flutter/foundation.dart';

class TokenException implements Exception {
  TokenException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TokenSpendException implements Exception {
  TokenSpendException({required this.code, required this.userMessage});

  final String code;
  final String userMessage;

  @override
  String toString() => '$code: $userMessage';
}

class TokenService {
  TokenService._();

  static final TokenService instance = TokenService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final ValueNotifier<AppUser?> liveUser = ValueNotifier(null);

  StreamSubscription<AppUser>? _liveUserSub;
  String? _boundUid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  /// Firestore `tokens` alanını güvenli okur (int / double / string).
  static int parseTokenBalance(dynamic raw, {required String uid}) {
    if (raw == null) {
      debugPrint('USER_TOKEN_FIELD_MISSING uid=$uid value=null');
      return 0;
    }
    if (raw is int) return raw;
    if (raw is double) return raw.floor();
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) return parsed;
      debugPrint('USER_TOKEN_FIELD_MISSING uid=$uid invalid_string=$raw');
      return 0;
    }
    debugPrint('USER_TOKEN_FIELD_MISSING uid=$uid type=${raw.runtimeType}');
    return 0;
  }

  Stream<AppUser> watchUser(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      if (!snap.exists) {
        return AppUser(userId: uid, name: '', email: '', tokens: 0);
      }
      return AppUser.fromFirestore(uid, snap.data()!);
    });
  }

  void bindLiveUser(String uid) {
    if (_boundUid == uid && _liveUserSub != null) return;

    _liveUserSub?.cancel();
    _boundUid = uid;

    _liveUserSub = watchUser(uid).listen(
      (user) {
        liveUser.value = user;
        debugPrint('TOKEN LIVE UPDATE: ${user.tokens}');
      },
      onError: (Object e, StackTrace stackTrace) {
        debugPrint('TOKEN LIVE STREAM ERROR: $e');
        debugPrint(stackTrace.toString());
      },
    );
  }

  void unbindLiveUser() {
    _liveUserSub?.cancel();
    _liveUserSub = null;
    _boundUid = null;
    liveUser.value = null;
  }

  void _applyOptimisticTokens(String uid, int delta) {
    final current = liveUser.value;
    if (current == null || current.userId != uid) return;
    liveUser.value = current.copyWith(tokens: current.tokens + delta);
  }

  void _applyOptimisticRewardClaim(String uid) {
    final current = liveUser.value;
    if (current == null || current.userId != uid) return;
    final used = rewardedAdsUsedToday(current);
    liveUser.value = current.copyWith(
      tokens: current.tokens + rewardAdTokenGrant,
      rewardedAdsToday: used + 1,
      lastRewardAt: DateTime.now(),
    );
  }

  Future<AppUser> fetchUser(String uid) async {
    final snap = await _userRef(uid).get();
    if (!snap.exists) {
      return AppUser(userId: uid, name: '', email: '', tokens: 0);
    }
    return AppUser.fromFirestore(uid, snap.data()!);
  }

  Future<int> readTokenBalance(String uid) async {
    try {
      final snap = await _userRef(uid).get();
      if (!snap.exists) {
        debugPrint('USER_TOKEN_FIELD_MISSING uid=$uid reason=user_doc_missing');
        return 0;
      }
      return parseTokenBalance(snap.data()?['tokens'], uid: uid);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('FIRESTORE_PERMISSION_DENIED uid=$uid');
      }
      rethrow;
    }
  }

  /// Kayıt sırasında gönderilen user doc payload'unu rules ile karşılaştırmak için loglar.
  static void logRegisterUserDocCreatePayload(Map<String, dynamic> data) {
    debugPrint(
      'REGISTER_USER_DOC_CREATE_PAYLOAD_KEYS: ${data.keys.join(', ')}',
    );
    debugPrint('REGISTER_USER_DOC_CREATE_TOKENS: ${data['tokens']}');
    debugPrint('REGISTER_USER_DOC_CREATE_EMAIL: ${data['email']}');
    debugPrint('REGISTER_USER_DOC_CREATE_UID: ${data['uid']}');
    debugPrint(
      'REGISTER_USER_DOC_CREATE_REFERRED_BY: '
      '${data.containsKey('referredBy') ? data['referredBy'] : '<absent>'}',
    );
  }

  Map<String, dynamic> _newUserDocumentData({
    required String uid,
    required String displayName,
    required String normalizedEmail,
  }) {
    final data = <String, dynamic>{
      'uid': uid,
      'name': displayName,
      'displayName': displayName,
      'email': normalizedEmail,
      'tokens': initialUserTokens,
      'specialFortuneRights': 0,
      'rewardedAdsToday': 0,
      'emailVerified': false,
      'referralRewardClaimed': false,
      'profileCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final platform = _currentMobilePlatform();
    if (platform != null) data['platform'] = platform;
    return data;
  }

  String? _currentMobilePlatform() {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return null;
  }

  /// Kullanıcı dokümanını oluşturur veya eksik jeton alanlarını tamamlar.
  Future<AppUser> ensureUserDocument({
    required String uid,
    String? name,
    String? email,
  }) async {
    debugPrint('NEW_USER_DOC_CHECK uid=$uid');
    final ref = _userRef(uid);
    final snap = await ref.get();

    if (!snap.exists) {
      final normalizedEmail = email?.trim().toLowerCase() ?? '';
      final displayName = name?.trim() ?? '';
      final data = _newUserDocumentData(
        uid: uid,
        displayName: displayName,
        normalizedEmail: normalizedEmail,
      );
      logRegisterUserDocCreatePayload(data);
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ref);
        if (!existing.exists) {
          tx.set(ref, data);
        }
      });
      final created = await ref.get();
      if (!created.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'aborted',
          message: 'User document could not be created',
        );
      }
      debugPrint('NEW_USER_DOC_CREATED uid=$uid tokens=$initialUserTokens');
      debugPrint('ENSURE_USER_DOC_RECOVERY_SUCCESS uid=$uid');
      final user = AppUser(
        userId: uid,
        name: displayName,
        displayName: displayName,
        email: normalizedEmail,
        tokens: initialUserTokens,
      );
      if (_boundUid == uid) {
        liveUser.value = user;
      }
      return user;
    }

    final data = snap.data()!;
    final updates = <String, dynamic>{};
    if (!data.containsKey('tokens') || data['tokens'] == null) {
      debugPrint('USER_TOKEN_FIELD_MISSING uid=$uid action=set_default');
      updates['tokens'] = initialUserTokens;
    }
    if (!data.containsKey('rewardedAdsToday')) {
      updates['rewardedAdsToday'] = 0;
    }
    final currentPlatform = _currentMobilePlatform();
    if (currentPlatform != null && data['platform'] != currentPlatform) {
      updates['platform'] = currentPlatform;
      updates['platformUpdatedAt'] = FieldValue.serverTimestamp();
    }
    if (updates.isNotEmpty) {
      await ref.update(updates);
    }

    final merged = {...data, ...updates};
    final user = AppUser.fromFirestore(uid, merged);
    if (_boundUid == uid) {
      liveUser.value = user;
    }
    return user;
  }

  /// Google girişi sonrası Firestore profil senkronizasyonu.
  /// Yeni kullanıcıda belge oluşturur; mevcut kullanıcıda jeton/profil korunur.
  Future<AppUser> syncGoogleUserDocument({
    required String uid,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    final ref = _userRef(uid);
    final snap = await ref.get();
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = displayName.trim();
    final trimmedPhoto = photoUrl?.trim();

    if (!snap.exists) {
      final data =
          _newUserDocumentData(
              uid: uid,
              displayName: trimmedName,
              normalizedEmail: normalizedEmail,
            )
            ..['emailVerified'] = true
            ..['provider'] = 'google'
            ..['lastLoginAt'] = FieldValue.serverTimestamp();
      if (trimmedPhoto != null && trimmedPhoto.isNotEmpty) {
        data['photoUrl'] = trimmedPhoto;
      }
      logRegisterUserDocCreatePayload(data);
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ref);
        if (!existing.exists) {
          tx.set(ref, data);
        }
      });
      final created = await ref.get();
      if (!created.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'aborted',
          message: 'Google user document could not be created',
        );
      }
      debugPrint('GOOGLE_USER_DOC_CREATED uid=$uid');
      final user = AppUser(
        userId: uid,
        name: trimmedName,
        displayName: trimmedName,
        email: normalizedEmail,
        tokens: initialUserTokens,
        emailVerified: true,
      );
      if (_boundUid == uid) {
        liveUser.value = user;
      }
      return user;
    }

    final existing = snap.data() ?? {};
    final updates = <String, dynamic>{
      'provider': 'google',
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'emailVerified': true,
    };
    final currentPlatform = _currentMobilePlatform();
    if (currentPlatform != null) {
      updates['platform'] = currentPlatform;
      updates['platformUpdatedAt'] = FieldValue.serverTimestamp();
    }

    final existingDisplay =
        (existing['displayName'] as String? ??
                existing['name'] as String? ??
                '')
            .trim();
    if (trimmedName.isNotEmpty &&
        (existingDisplay.isEmpty || existingDisplay == trimmedName)) {
      updates['displayName'] = trimmedName;
      if ((existing['name'] as String? ?? '').trim().isEmpty) {
        updates['name'] = trimmedName;
      }
    }

    if (trimmedPhoto != null && trimmedPhoto.isNotEmpty) {
      updates['photoUrl'] = trimmedPhoto;
    }

    await ref.update(updates);

    final merged = {...existing, ...updates};
    final user = AppUser.fromFirestore(
      uid,
      merged,
    ).copyWith(emailVerified: true);
    if (_boundUid == uid) {
      liveUser.value = user;
    }
    return user;
  }

  @Deprecated('Use ensureUserDocument')
  Future<void> ensureUserDefaults(String uid) async {
    await ensureUserDocument(uid: uid);
  }

  Future<void> spendTokens(String uid, int amount) async {
    debugPrint('TOKEN_TRANSACTION_START uid=$uid amount=$amount');
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_userRef(uid));
        if (!snap.exists) {
          debugPrint('FORTUNE_SUBMIT_FAILED_REASON user_doc_missing_in_tx');
          throw TokenSpendException(
            code: 'user_doc_missing',
            userMessage: fortuneSubmitUserDocError,
          );
        }

        final balance = parseTokenBalance(snap.data()?['tokens'], uid: uid);
        debugPrint('USER_TOKEN_BALANCE_BEFORE: $balance');
        debugPrint('FORTUNE_COST: $amount');

        if (balance < amount) {
          debugPrint('FORTUNE_SUBMIT_FAILED_REASON insufficient_balance_in_tx');
          throw TokenSpendException(
            code: 'insufficient_balance',
            userMessage: fortuneSubmitInsufficientBalance,
          );
        }

        tx.update(_userRef(uid), {'tokens': balance - amount});
      });

      debugPrint('TOKEN_TRANSACTION_SUCCESS uid=$uid amount=$amount');
      _applyOptimisticTokens(uid, -amount);
    } on TokenSpendException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('FIRESTORE_PERMISSION_DENIED uid=$uid');
        throw TokenSpendException(
          code: 'permission_denied',
          userMessage: fortuneSubmitPermissionError,
        );
      }
      debugPrint('TOKEN spend Firebase error: ${e.code} ${e.message}');
      throw TokenSpendException(
        code: 'firestore_error',
        userMessage: fortuneSubmitServerError,
      );
    } catch (e, stackTrace) {
      debugPrint('TOKEN spend error: $e');
      debugPrint(stackTrace.toString());
      if (e is TokenSpendException) rethrow;
      throw TokenSpendException(
        code: 'unknown',
        userMessage: fortuneSubmitServerError,
      );
    }
  }

  /// Geriye uyumluluk — başarılı ise true, aksi halde false (exception atmaz).
  Future<bool> spendTokensLegacy(String uid, int amount) async {
    try {
      await spendTokens(uid, amount);
      return true;
    } on TokenSpendException {
      return false;
    }
  }

  Future<void> addTokens(String uid, int amount) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_userRef(uid));
      if (!snap.exists) return;

      final tokens = parseTokenBalance(snap.data()?['tokens'], uid: uid);
      tx.update(_userRef(uid), {'tokens': tokens + amount});
    });
    _applyOptimisticTokens(uid, amount);
  }

  int rewardedAdsUsedToday(AppUser user) => _effectiveRewardCount(user);

  String rewardAdQuotaLabel(AppUser user) {
    final used = rewardedAdsUsedToday(user);
    return 'Bugünkü reklam hakkı: $used/$maxRewardedAdsPerDay';
  }

  int remainingRewardAds(AppUser user) {
    final effectiveCount = _effectiveRewardCount(user);
    return (maxRewardedAdsPerDay - effectiveCount).clamp(
      0,
      maxRewardedAdsPerDay,
    );
  }

  /// Türkiye (UTC+3) takvim günü değiştiyse reklam hakkı sıfırlanır.
  static bool isRewardPeriodElapsed(DateTime? lastRewardAt) {
    if (lastRewardAt == null) return false;
    final lastKey = DailyHoroscopeService.istanbulDateKey(lastRewardAt.toUtc());
    final todayKey = DailyHoroscopeService.istanbulDateKey();
    return lastKey != todayKey;
  }

  int _effectiveRewardCount(AppUser user) {
    if (isRewardPeriodElapsed(user.lastRewardAt)) return 0;
    final count = user.rewardedAdsToday;
    if (count >= maxRewardedAdsPerDay) return maxRewardedAdsPerDay;
    return count;
  }

  /// Sonraki Türkiye 00:00'a kalan süre (hak bitince).
  Duration? timeUntilRewardReset(AppUser user) {
    if (remainingRewardAds(user) > 0) return null;
    if (isRewardPeriodElapsed(user.lastRewardAt)) return null;

    final nowUtc = DateTime.now().toUtc();
    final istanbulNow = nowUtc.add(const Duration(hours: 3));
    final nextMidnightIstanbul = DateTime(
      istanbulNow.year,
      istanbulNow.month,
      istanbulNow.day + 1,
    );
    final nextMidnightUtc = nextMidnightIstanbul.subtract(
      const Duration(hours: 3),
    );
    final remaining = nextMidnightUtc.difference(nowUtc);
    if (remaining <= Duration.zero) return null;
    return remaining;
  }

  String rewardAdWaitMessage(AppUser user) => rewardAdLimitReachedMessage;

  Future<void> claimRewardedAd(
    String uid, {
    bool isCompensation = false,
    String? compensationReason,
  }) async {
    debugPrint('DAILY_REWARD_LIMIT=$maxRewardedAdsPerDay');
    debugPrint('REWARDED_CLAIM_ATTEMPT uid=$uid');
    try {
      await _db.runTransaction((tx) async {
        final ref = _userRef(uid);
        final snap = await tx.get(ref);
        if (!snap.exists) throw TokenException('Kullanıcı bulunamadı');

        final data = snap.data()!;
        var adsToday = (data['rewardedAdsToday'] as num?)?.toInt() ?? 0;
        final tokens = parseTokenBalance(data['tokens'], uid: uid);
        final lastRaw = data['lastRewardAt'];
        DateTime? lastReward;
        if (lastRaw is Timestamp) lastReward = lastRaw.toDate();

        if (isRewardPeriodElapsed(lastReward)) {
          adsToday = 0;
        }

        if (adsToday >= maxRewardedAdsPerDay) {
          debugPrint(
            'REWARDED_CLAIM_LIMIT_REACHED uid=$uid adsToday=$adsToday',
          );
          throw TokenException(rewardAdLimitReachedMessage);
        }

        final newTokens = tokens + rewardAdTokenGrant;
        tx.update(ref, {
          'tokens': newTokens,
          'rewardedAdsToday': adsToday + 1,
          'lastRewardAt': Timestamp.fromDate(DateTime.now()),
        });

        debugPrint(
          'REWARDED_CLAIM_SUCCESS: tokens $tokens -> $newTokens (+$rewardAdTokenGrant)',
        );
      });

      _applyOptimisticRewardClaim(uid);
      unawaited(
        StatisticsService.instance.logRewardedAd(
          uid,
          isCompensation: isCompensation,
          compensationReason: compensationReason,
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('REWARDED CLAIM ERROR: Firebase ${e.code} ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('REWARDED CLAIM ERROR: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// Fal formundan gelen yaş/burç bilgisini profilde saklar (jeton alanlarına dokunmaz).
  Future<void> mergeProfileFields({
    required String uid,
    int? age,
    String? zodiac,
  }) async {
    final data = <String, dynamic>{};
    if (age != null && age > 0) data['age'] = age;
    final z = zodiac?.trim();
    if (z != null && z.isNotEmpty) data['zodiac'] = z;
    if (data.isEmpty) return;

    data['updatedAt'] = FieldValue.serverTimestamp();
    await _userRef(uid).set(data, SetOptions(merge: true));
  }

  Future<void> mockPurchase(String uid, int amount) async {
    if (!kDebugMode) {
      throw TokenException('Satın alma henüz aktif değil.');
    }
    await addTokens(uid, amount);
    if (kDebugMode) {
      debugPrint('TOKEN mock purchase: +$amount');
    }
  }
}
