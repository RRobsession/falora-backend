import 'package:falora/config/avatar_catalog.dart';
import 'package:falora/widgets/user_avatar_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/utils/profile_age.dart';

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
    this.displayName = '',
    this.birthDate,
    this.profileCompleted = false,
    this.avatarAsset,
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
  final String displayName;
  final DateTime? birthDate;
  final bool profileCompleted;
  final String? avatarAsset;

  String get effectiveDisplayName {
    final fromDisplay = displayName.trim();
    if (fromDisplay.isNotEmpty) return fromDisplay;
    return name.trim();
  }

  int? get computedAge {
    if (birthDate != null) {
      return calculateAgeFromBirthDate(birthDate!);
    }
    return age;
  }

  bool get hasProfileDetails =>
      (computedAge != null && computedAge! > 0) ||
      (zodiac != null && zodiac!.isNotEmpty);

  AppUser copyWith({
    String? name,
    String? email,
    int? tokens,
    int? rewardedAdsToday,
    DateTime? lastRewardAt,
    bool? emailVerified,
    int? age,
    String? zodiac,
    String? displayName,
    DateTime? birthDate,
    bool? profileCompleted,
    String? avatarAsset,
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
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      avatarAsset: avatarAsset ?? this.avatarAsset,
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

    DateTime? birthDate;
    final birthRaw = json['birthDate'];
    if (birthRaw is Timestamp) {
      birthDate = birthRaw.toDate();
    }

    final resolvedName = displayNameFromUserData(json);

    return AppUser(
      userId: uid,
      name: resolvedName,
      displayName: resolvedName,
      email: (json['email'] as String?)?.trim().toLowerCase() ?? '',
      tokens: TokenService.parseTokenBalance(json['tokens'], uid: uid),
      rewardedAdsToday: (json['rewardedAdsToday'] as num?)?.toInt() ?? 0,
      lastRewardAt: lastReward,
      age: displayAgeFromUserData(json),
      zodiac: _parseZodiac(json['zodiac']),
      birthDate: birthDate,
      profileCompleted: json['profileCompleted'] == true,
      avatarAsset: _parseOptionalString(
        _normalizeAvatarFromFirestore(json['avatarAsset'] as String?),
      ),
    );
  }

  static String? _parseZodiac(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeAvatarFromFirestore(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (isCustomAvatarAsset(raw)) return raw.trim();
    return normalizeStoredAvatarAsset(raw);
  }

  static String? _parseOptionalString(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
