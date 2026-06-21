import 'dart:async';



import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:falora/models/app_user.dart';

import 'package:falora/token_config.dart';

import 'package:flutter/foundation.dart';



class TokenException implements Exception {

  TokenException(this.message);

  final String message;



  @override

  String toString() => message;

}



class TokenService {

  TokenService._();



  static final TokenService instance = TokenService._();



  final FirebaseFirestore _db = FirebaseFirestore.instance;



  /// Uygulama genelinde tek jeton kaynağı — Firestore snapshot ile güncellenir.

  final ValueNotifier<AppUser?> liveUser = ValueNotifier(null);



  StreamSubscription<AppUser>? _liveUserSub;

  String? _boundUid;



  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>

      _db.collection('users').doc(uid);



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



  Future<AppUser> fetchUser(String uid) async {

    final snap = await _userRef(uid).get();

    if (!snap.exists) {

      return AppUser(userId: uid, name: '', email: '', tokens: 0);

    }

    return AppUser.fromFirestore(uid, snap.data()!);

  }



  Future<void> ensureUserDefaults(String uid) async {

    final ref = _userRef(uid);

    final snap = await ref.get();

    if (!snap.exists) return;



    final data = snap.data()!;

    final updates = <String, dynamic>{};

    if (!data.containsKey('tokens')) updates['tokens'] = initialUserTokens;

    if (!data.containsKey('rewardedAdsToday')) updates['rewardedAdsToday'] = 0;

    if (updates.isNotEmpty) {

      await ref.update(updates);

    }

  }



  Future<bool> spendTokens(String uid, int amount) async {

    try {

      final ok = await _db.runTransaction<bool>((tx) async {

        final snap = await tx.get(_userRef(uid));

        if (!snap.exists) return false;



        final tokens = (snap.data()?['tokens'] as num?)?.toInt() ?? 0;

        if (tokens < amount) return false;



        tx.update(_userRef(uid), {'tokens': tokens - amount});

        return true;

      });

      if (ok) {

        _applyOptimisticTokens(uid, -amount);

      }

      return ok;

    } on FirebaseException catch (e) {

      debugPrint('TOKEN spend Firebase error: ${e.code} ${e.message}');

      rethrow;

    } catch (e, stackTrace) {

      debugPrint('TOKEN spend error: $e');

      debugPrint(stackTrace.toString());

      rethrow;

    }

  }



  Future<void> addTokens(String uid, int amount) async {

    await _db.runTransaction((tx) async {

      final snap = await tx.get(_userRef(uid));

      if (!snap.exists) return;



      final tokens = (snap.data()?['tokens'] as num?)?.toInt() ?? 0;

      tx.update(_userRef(uid), {'tokens': tokens + amount});

    });

    _applyOptimisticTokens(uid, amount);

  }



  int remainingRewardAds(AppUser user) {

    final effectiveCount = _effectiveRewardCount(user);

    return (maxRewardedAdsPerDay - effectiveCount).clamp(0, maxRewardedAdsPerDay);

  }



  int _effectiveRewardCount(AppUser user) {

    var count = user.rewardedAdsToday;

    if (user.lastRewardAt != null) {

      final elapsed = DateTime.now().difference(user.lastRewardAt!);

      if (elapsed >= rewardResetDuration) return 0;

    }

    if (count >= maxRewardedAdsPerDay) return maxRewardedAdsPerDay;

    return count;

  }



  Duration? timeUntilRewardReset(AppUser user) {

    if (remainingRewardAds(user) > 0) return null;

    if (user.lastRewardAt == null) return rewardResetDuration;

    final elapsed = DateTime.now().difference(user.lastRewardAt!);

    if (elapsed >= rewardResetDuration) return null;

    return rewardResetDuration - elapsed;

  }



  String rewardAdWaitMessage(AppUser user) {

    return 'Bugünkü ücretsiz jeton hakkını kullandın.';

  }



  Future<void> claimRewardedAd(String uid) async {

    await _db.runTransaction((tx) async {

      final ref = _userRef(uid);

      final snap = await tx.get(ref);

      if (!snap.exists) throw TokenException('Kullanıcı bulunamadı');



      final data = snap.data()!;

      var adsToday = (data['rewardedAdsToday'] as num?)?.toInt() ?? 0;

      final tokens = (data['tokens'] as num?)?.toInt() ?? 0;

      final lastRaw = data['lastRewardAt'];

      DateTime? lastReward;

      if (lastRaw is Timestamp) lastReward = lastRaw.toDate();



      if (lastReward != null &&

          DateTime.now().difference(lastReward) >= rewardResetDuration) {

        adsToday = 0;

      }



      if (adsToday >= maxRewardedAdsPerDay) {
        throw TokenException('Bugünkü ücretsiz jeton hakkını kullandın.');
      }

      final newTokens = tokens + rewardAdTokenGrant;
      tx.update(ref, {
        'tokens': newTokens,
        'rewardedAdsToday': adsToday + 1,
        'lastRewardAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint(
        'REWARDED CLAIM SUCCESS: tokens $tokens -> $newTokens (+$rewardAdTokenGrant)',
      );

    });

    _applyOptimisticTokens(uid, rewardAdTokenGrant);

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


