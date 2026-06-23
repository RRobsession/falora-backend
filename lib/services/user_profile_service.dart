import 'dart:typed_data';

import 'package:falora/config/avatar_catalog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/utils/profile_age.dart';
import 'package:falora/widgets/user_avatar_image.dart';
import 'package:flutter/foundation.dart';

enum ProfileOnboardingStep { name, birthDate, zodiac, avatar }

/// Profil tamamlama ve güncelleme işlemleri.
class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  static bool needsProfileCompletion(AppUser user) =>
      firstIncompleteStep(user) != null;

  static ProfileOnboardingStep? firstIncompleteStep(AppUser user) {
    if (user.profileCompleted) return null;
    if (user.displayName.trim().isEmpty) {
      return ProfileOnboardingStep.name;
    }
    if (user.birthDate == null || user.age == null || user.age! < 1) {
      return ProfileOnboardingStep.birthDate;
    }
    if (user.zodiac == null || user.zodiac!.trim().isEmpty) {
      return ProfileOnboardingStep.zodiac;
    }
    return ProfileOnboardingStep.avatar;
  }

  static int stepIndex(ProfileOnboardingStep step) => step.index;

  Future<void> saveDisplayName(String uid, String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('İsim boş olamaz');
    }
    debugPrint('ONBOARDING_NAME_STEP_START');
    await _userRef(uid).set(
      {
        'displayName': trimmed,
        'name': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    debugPrint('ONBOARDING_NAME_SAVED');
  }

  Future<void> saveBirthDate(String uid, DateTime birthDate) async {
    debugPrint('ONBOARDING_BIRTHDATE_STEP_START');
    final age = calculateAgeFromBirthDate(birthDate);
    await _userRef(uid).set(
      {
        'birthDate': Timestamp.fromDate(
          DateTime(birthDate.year, birthDate.month, birthDate.day),
        ),
        'age': age,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    debugPrint('ONBOARDING_BIRTHDATE_SAVED');
  }

  Future<void> saveZodiac(String uid, String zodiac) async {
    final trimmed = zodiac.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Burç seçilmelidir');
    }
    debugPrint('ONBOARDING_ZODIAC_STEP_START');
    await _userRef(uid).set(
      {
        'zodiac': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    debugPrint('ONBOARDING_ZODIAC_SAVED');
  }

  Future<void> saveAvatarAsset(String uid, String avatarAsset) async {
    final trimmed = avatarAsset.trim();
    final stored = isCustomAvatarAsset(trimmed)
        ? trimmed
        : normalizeStoredAvatarAsset(trimmed);
    debugPrint('ONBOARDING_AVATAR_STEP_START');
    await _userRef(uid).set(
      {
        'avatarAsset': stored,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    debugPrint('ONBOARDING_AVATAR_SELECTED asset=${stored.length > 80 ? '${stored.substring(0, 40)}…' : stored}');
  }

  Future<void> saveGalleryAvatar(String uid, Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('Görsel boş');
    }
    final encoded = encodeCustomAvatarBytes(imageBytes);
    await saveAvatarAsset(uid, encoded);
  }

  Future<void> completeProfile(String uid) async {
    await _userRef(uid).set(
      {
        'profileCompleted': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    debugPrint('ONBOARDING_COMPLETED');
  }

  Future<void> clearAvatarAsset(String uid) async {
    await _userRef(uid).set(
      {
        'avatarAsset': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
