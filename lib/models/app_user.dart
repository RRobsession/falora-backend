import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/services/token_service.dart';

class AppUser {
  const AppUser({
    required this.userId,
    required this.name,
    required this.email,
    this.tokens = 0,
    this.rewardedAdsToday = 0,
    this.lastRewardAt,
    this.emailVerified = false,
    this.age,
    this.zodiac,
  });

  final String userId;
  final String name;
  final String email;
  final int tokens;
  final int rewardedAdsToday;
  final DateTime? lastRewardAt;
  final bool emailVerified;
  final int? age;
  final String? zodiac;

  bool get hasProfileDetails =>
      (age != null && age! > 0) || (zodiac != null && zodiac!.isNotEmpty);

  AppUser copyWith({
    String? name,
    String? email,
    int? tokens,
    int? rewardedAdsToday,
    DateTime? lastRewardAt,
    bool? emailVerified,
    int? age,
    String? zodiac,
  }) {
    return AppUser(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      tokens: tokens ?? this.tokens,
      rewardedAdsToday: rewardedAdsToday ?? this.rewardedAdsToday,
      lastRewardAt: lastRewardAt ?? this.lastRewardAt,
      emailVerified: emailVerified ?? this.emailVerified,
      age: age ?? this.age,
      zodiac: zodiac ?? this.zodiac,
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
      tokens: TokenService.parseTokenBalance(json['tokens'], uid: uid),
      rewardedAdsToday: (json['rewardedAdsToday'] as num?)?.toInt() ?? 0,
      lastRewardAt: lastReward,
      age: (json['age'] as num?)?.toInt(),
      zodiac: _parseZodiac(json['zodiac']),
      // emailVerified yalnızca Firebase Auth'tan okunur; Firestore alanı kullanılmaz.
    );
  }

  static String? _parseZodiac(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
