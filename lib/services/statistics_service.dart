import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.fortunes,
    required this.rewardedAds,
    required this.rewardedAdViewers,
    required this.compensationGrants,
    required this.compensationUsers,
    required this.rewardTokenAds,
    required this.unlockAds,
    required this.failedAds,
    required this.cancelledAds,
    required this.legacyUnknownAds,
    required this.shownAds,
    required this.impressionAds,
    required this.clickedAds,
    required this.hourlyActiveUsers,
    required this.activeUsers,
    required this.dailyActiveUsers,
    required this.totalRegisteredUsers,
    required this.newRegisteredUsers,
  });

  final Map<String, int> fortunes;
  final int rewardedAds;
  final int rewardedAdViewers;
  final int compensationGrants;
  final int compensationUsers;
  final int rewardTokenAds;
  final int unlockAds;
  final int failedAds;
  final int cancelledAds;
  final int legacyUnknownAds;
  final int shownAds;
  final int impressionAds;
  final int clickedAds;
  final List<int> hourlyActiveUsers;
  final int activeUsers;
  final Map<DateTime, int> dailyActiveUsers;
  final int totalRegisteredUsers;
  final int newRegisteredUsers;

  int get totalFortunes => fortunes.values.fold(0, (a, b) => a + b);
}

class FortuneStatistics {
  const FortuneStatistics(this.fortunes);
  final Map<String, int> fortunes;
  int get total => fortunes.values.fold(0, (a, b) => a + b);
}

class AdStatistics {
  const AdStatistics({
    required this.views,
    required this.viewers,
    required this.compensationGrants,
    required this.compensationUsers,
    required this.rewardTokenAds,
    required this.unlockAds,
    required this.failedAds,
    required this.cancelledAds,
    required this.legacyUnknownAds,
    required this.shownAds,
    required this.impressionAds,
    required this.clickedAds,
  });
  final int views;
  final int viewers;
  final int compensationGrants;
  final int compensationUsers;
  final int rewardTokenAds;
  final int unlockAds;
  final int failedAds;
  final int cancelledAds;
  final int legacyUnknownAds;
  final int shownAds;
  final int impressionAds;
  final int clickedAds;
}

class ActivityStatistics {
  const ActivityStatistics({
    required this.hours,
    required this.users,
    required this.days,
  });
  final List<int> hours;
  final int users;
  final Map<DateTime, int> days;
}

class UserStatistics {
  const UserStatistics({required this.total, required this.registeredInRange});
  final int total;
  final int registeredInRange;
  bool get isAvailable => total >= 0;
}

/// Uygulama kullanım olayları ve canlı presence için tek merkez.
class StatisticsService {
  StatisticsService._();
  static final instance = StatisticsService._();

  // Uygulama kapanışında çevrimdışı işareti hemen yazılır. Beklenmeyen kapanış
  // durumunda eski oturumların canlı sayılmaması için kısa bir güvenlik penceresi.
  static const _heartbeatInterval = Duration(minutes: 10);
  static const _liveUserWindow = Duration(minutes: 12);

  final _db = FirebaseFirestore.instance;
  Timer? _heartbeat;
  StreamSubscription<User?>? _authSubscription;
  bool _isForeground = true;
  String? _lastActivityKey;

  void init() {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((_) {
      if (_isForeground) _startHeartbeat();
    });
    _startHeartbeat();
  }

  void onLifecycleChanged(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _startHeartbeat();
    } else {
      _heartbeat?.cancel();
      _heartbeat = null;
      unawaited(_markOffline());
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    unawaited(_sendHeartbeat());
    _heartbeat = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(_sendHeartbeat()),
    );
  }

  Future<void> _sendHeartbeat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!_isForeground || uid == null) return;
    try {
      final now = DateTime.now();
      final bucket = DateTime(now.year, now.month, now.day, now.hour);
      final activityKey =
          '${_dateKey(now)}_${now.hour.toString().padLeft(2, '0')}_$uid';
      final batch = _db.batch();
      batch.set(_db.collection('app_presence').doc(uid), {
        'userId': uid,
        'isForeground': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (_lastActivityKey != activityKey) {
        batch.set(
          _db.collection('app_activity_hours').doc(activityKey),
          {
            'userId': uid,
            'hour': now.hour,
            'bucketAt': Timestamp.fromDate(bucket),
            'lastSeenAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      _lastActivityKey = activityKey;
    } catch (e) {
      debugPrint('STATISTICS heartbeat error: $e');
    }
  }

  Future<void> _markOffline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('app_presence').doc(uid).set({
        'isForeground': false,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> logRewardedAd(
    String uid, {
    required bool isCompensation,
    String? compensationReason,
  }) async {
    try {
      await _db.collection('statistics_events').add({
        'type': 'rewarded_ad',
        'userId': uid,
        'isCompensation': isCompensation,
        'outcome': isCompensation ? 'compensation' : 'completed',
        'placement': 'reward_tokens',
        if (compensationReason != null) 'compensationReason': compensationReason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('STATISTICS rewarded ad error: $e');
    }
  }

  Future<void> logAdOutcome(
    String uid, {
    required String outcome,
    required String placement,
    String? reason,
  }) async {
    try {
      await _db.collection('statistics_events').add({
        'type': 'rewarded_ad',
        'userId': uid,
        'outcome': outcome,
        'placement': placement,
        'isCompensation': outcome == 'compensation',
        if (reason != null) 'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('STATISTICS ad outcome error: $e');
    }
  }

  Future<int> loadLiveUsers() async {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(_liveUserWindow),
    );
    final snap = await _db
        .collection('app_presence')
        .where('lastSeenAt', isGreaterThanOrEqualTo: cutoff)
        .get();
    return snap.docs.where((d) => d.data()['isForeground'] == true).length;
  }

  Future<StatisticsSnapshot> load(DateTime start, DateTime endExclusive) async {
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(endExclusive);
    final results = await Future.wait([
      _range('fortune_requests', startTs, endTs),
      _range('couple_compatibility_requests', startTs, endTs),
      _range('manual_fortune_requests', startTs, endTs),
      _range('statistics_events', startTs, endTs),
      _activityRange(startTs, endTs),
      _userCounts(startTs, endTs),
    ]);
    final fortunes = <String, int>{};
    for (final doc
        in results[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>) {
      final data = doc.data();
      _increment(
        fortunes,
        (data['category'] ?? data['title'] ?? 'Diğer').toString(),
      );
    }
    fortunes['Çift Uyumu'] = (results[1] as List).length;
    for (final doc
        in results[2] as List<QueryDocumentSnapshot<Map<String, dynamic>>>) {
      final data = doc.data();
      _increment(
        fortunes,
        (data['fortuneType'] ?? data['category'] ?? 'Manuel Fal').toString(),
      );
    }
    final adEvents =
        (results[3] as List<QueryDocumentSnapshot<Map<String, dynamic>>>)
            .where((d) => d.data()['type'] == 'rewarded_ad')
            .toList();
    final compensationEvents = adEvents
        .where((d) => d.data()['outcome'] == 'compensation')
        .toList();
    final completedEvents = adEvents
        .where((d) => d.data()['outcome'] == 'completed')
        .toList();
    final compensationUsers = compensationEvents
        .map((d) => d.data()['userId']?.toString())
        .whereType<String>()
        .toSet()
        .length;
    final activity = results[4] as _ActivityResult;
    final userCounts = results[5] as _UserCounts;
    return StatisticsSnapshot(
      fortunes: fortunes..removeWhere((_, value) => value == 0),
      rewardedAds: completedEvents.length,
      rewardedAdViewers: completedEvents
          .map((d) => d.data()['userId']?.toString())
          .whereType<String>()
          .toSet()
          .length,
      compensationGrants: compensationEvents.length,
      compensationUsers: compensationUsers,
      rewardTokenAds: completedEvents.where((d) => d.data()['placement'] == 'reward_tokens').length,
      unlockAds: completedEvents.where((d) => d.data()['placement'] == 'yes_no_unlock').length,
      failedAds: adEvents.where((d) => d.data()['outcome'] == 'failed').length,
      cancelledAds: adEvents.where((d) => d.data()['outcome'] == 'cancelled').length,
      legacyUnknownAds: adEvents.where((d) => d.data()['outcome'] == null).length,
      shownAds: adEvents.where((d) => d.data()['outcome'] == 'shown').length,
      impressionAds: adEvents.where((d) => d.data()['outcome'] == 'impression').length,
      clickedAds: adEvents.where((d) => d.data()['outcome'] == 'clicked').length,
      hourlyActiveUsers: activity.hours,
      activeUsers: activity.users,
      dailyActiveUsers: activity.days,
      totalRegisteredUsers: userCounts.total,
      newRegisteredUsers: userCounts.registeredInRange,
    );
  }

  Future<FortuneStatistics> loadFortunes(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(endExclusive);
    final results = await Future.wait([
      _range('fortune_requests', startTs, endTs),
      _range('couple_compatibility_requests', startTs, endTs),
      _range('manual_fortune_requests', startTs, endTs),
    ]);
    final fortunes = <String, int>{};
    for (final doc in results[0]) {
      final data = doc.data();
      _increment(
        fortunes,
        (data['category'] ?? data['title'] ?? 'Diğer').toString(),
      );
    }
    fortunes['Çift Uyumu'] = results[1].length;
    for (final doc in results[2]) {
      final data = doc.data();
      _increment(
        fortunes,
        (data['fortuneType'] ?? data['category'] ?? 'Manuel Fal').toString(),
      );
    }
    fortunes.removeWhere((_, value) => value == 0);
    return FortuneStatistics(fortunes);
  }

  Future<AdStatistics> loadAds(DateTime start, DateTime endExclusive) async {
    final docs = await _range(
      'statistics_events',
      Timestamp.fromDate(start),
      Timestamp.fromDate(endExclusive),
    );
    final events = docs
        .where((d) => d.data()['type'] == 'rewarded_ad')
        .toList();
    final compensationEvents = events
        .where((d) => d.data()['outcome'] == 'compensation')
        .toList();
    final completedEvents = events
        .where((d) => d.data()['outcome'] == 'completed')
        .toList();
    final compensationUsers = compensationEvents
        .map((d) => d.data()['userId']?.toString())
        .whereType<String>()
        .toSet()
        .length;
    return AdStatistics(
      views: completedEvents.length,
      viewers: completedEvents
          .map((d) => d.data()['userId']?.toString())
          .whereType<String>()
          .toSet()
          .length,
      compensationGrants: compensationEvents.length,
      compensationUsers: compensationUsers,
      rewardTokenAds: completedEvents.where((d) => d.data()['placement'] == 'reward_tokens').length,
      unlockAds: completedEvents.where((d) => d.data()['placement'] == 'yes_no_unlock').length,
      failedAds: events.where((d) => d.data()['outcome'] == 'failed').length,
      cancelledAds: events.where((d) => d.data()['outcome'] == 'cancelled').length,
      legacyUnknownAds: events.where((d) => d.data()['outcome'] == null).length,
      shownAds: events.where((d) => d.data()['outcome'] == 'shown').length,
      impressionAds: events.where((d) => d.data()['outcome'] == 'impression').length,
      clickedAds: events.where((d) => d.data()['outcome'] == 'clicked').length,
    );
  }

  Future<ActivityStatistics> loadActivity(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final result = await _activityRange(
      Timestamp.fromDate(start),
      Timestamp.fromDate(endExclusive),
    );
    return ActivityStatistics(
      hours: result.hours,
      users: result.users,
      days: result.days,
    );
  }

  Future<UserStatistics> loadUsers(
    DateTime start,
    DateTime endExclusive, {
    String? platform,
  }) async {
    final result = await _userCounts(
      Timestamp.fromDate(start),
      Timestamp.fromDate(endExclusive),
      platform: platform,
    );
    return UserStatistics(
      total: result.total,
      registeredInRange: result.registeredInRange,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _range(
    String collection,
    Timestamp start,
    Timestamp end,
  ) async =>
      (await _db
              .collection(collection)
              .where('createdAt', isGreaterThanOrEqualTo: start)
              .where('createdAt', isLessThan: end)
              .get())
          .docs;

  Future<_ActivityResult> _activityRange(Timestamp start, Timestamp end) async {
    final docs =
        (await _db
                .collection('app_activity_hours')
                .where('bucketAt', isGreaterThanOrEqualTo: start)
                .where('bucketAt', isLessThan: end)
                .get())
            .docs;
    final hours = List<int>.filled(24, 0);
    final allUsers = <String>{};
    final usersByDay = <DateTime, Set<String>>{};
    for (final doc in docs) {
      final data = doc.data();
      final hour = (data['hour'] as num?)?.toInt();
      if (hour != null && hour >= 0 && hour < 24) hours[hour]++;
      final uid = data['userId']?.toString();
      final bucket = data['bucketAt'];
      if (uid != null && bucket is Timestamp) {
        allUsers.add(uid);
        final date = bucket.toDate();
        final day = DateTime(date.year, date.month, date.day);
        usersByDay.putIfAbsent(day, () => <String>{}).add(uid);
      }
    }
    return _ActivityResult(
      hours: hours,
      users: allUsers.length,
      days: usersByDay.map((day, users) => MapEntry(day, users.length)),
    );
  }

  Future<_UserCounts> _userCounts(
    Timestamp start,
    Timestamp end, {
    String? platform,
  }) async {
    try {
      // iOS sürümü öncesindeki kullanıcı belgelerinde platform alanı yoktu ve
      // mevcut kullanıcı tabanı Android'di. Eski kayıtlara toplu yazma yapmadan
      // geriye uyumluluk için Android = Tümü - iOS olarak hesaplanır.
      if (platform == 'android') {
        final results = await Future.wait([
          _userCounts(start, end),
          _userCounts(start, end, platform: 'ios'),
        ]);
        final all = results[0];
        final ios = results[1];
        if (all.total < 0 || ios.total < 0) {
          return const _UserCounts(total: -1, registeredInRange: -1);
        }
        return _UserCounts(
          total: (all.total - ios.total).clamp(0, all.total),
          registeredInRange: (all.registeredInRange - ios.registeredInRange)
              .clamp(0, all.registeredInRange),
        );
      }
      final users = _db.collection('users');
      Query<Map<String, dynamic>> totalQuery = users;
      Query<Map<String, dynamic>> rangeQuery = users
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end);
      if (platform != null) {
        totalQuery = totalQuery.where('platform', isEqualTo: platform);
        rangeQuery = rangeQuery.where('platform', isEqualTo: platform);
      }
      final results = await Future.wait([
        totalQuery.count().get(),
        rangeQuery.count().get(),
      ]);
      return _UserCounts(
        total: results[0].count ?? 0,
        registeredInRange: results[1].count ?? 0,
      );
    } catch (e) {
      // Kullanıcı sayımı yetkisi henüz yayınlanmamış olsa bile fal, reklam ve
      // aktiflik istatistiklerinin tamamını bozma.
      debugPrint('STATISTICS user counts unavailable: $e');
      return const _UserCounts(total: -1, registeredInRange: -1);
    }
  }

  static void _increment(Map<String, int> map, String key) {
    map[key] = (map[key] ?? 0) + 1;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

class _ActivityResult {
  const _ActivityResult({
    required this.hours,
    required this.users,
    required this.days,
  });
  final List<int> hours;
  final int users;
  final Map<DateTime, int> days;
}

class _UserCounts {
  const _UserCounts({required this.total, required this.registeredInRange});
  final int total;
  final int registeredInRange;
}
