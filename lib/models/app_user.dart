import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.userId,
    required this.name,
    required this.email,
    this.tokens = 0,
    this.rewardedAdsToday = 0,
    this.lastRewardAt,
    this.emailVerified = false,
  });

  final String userId;
  final String name;
  final String email;
  final int tokens;
  final int rewardedAdsToday;
  final DateTime? lastRewardAt;
  final bool emailVerified;

  AppUser copyWith({
    String? name,
    String? email,
    int? tokens,
    int? rewardedAdsToday,
    DateTime? lastRewardAt,
    bool? emailVerified,
  }) {
    return AppUser(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      tokens: tokens ?? this.tokens,
      rewardedAdsToday: rewardedAdsToday ?? this.rewardedAdsToday,
      lastRewardAt: lastRewardAt ?? this.lastRewardAt,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'tokens': tokens,
        'rewardedAdsToday': rewardedAdsToday,
        'lastRewardAt': lastRewardAt?.toIso8601String(),
        'emailVerified': emailVerified,
      };

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> json) {
    DateTime? lastReward;
    final raw = json['lastRewardAt'];
    if (raw is Timestamp) {
      lastReward = raw.toDate();
    } else if (raw is String) {
      lastReward = DateTime.tryParse(raw);
    }

    return AppUser(
      userId: uid,
      name: (json['name'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim().toLowerCase() ?? '',
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      rewardedAdsToday: (json['rewardedAdsToday'] as num?)?.toInt() ?? 0,
      lastRewardAt: lastReward,
      // emailVerified yalnızca Firebase Auth'tan okunur; Firestore alanı kullanılmaz.
    );
  }
}
