import 'package:falora/models/app_user.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Fal formlarına profil bilgilerini otomatik doldurma yardımcısı.
class FortuneFormPrefill {
  const FortuneFormPrefill({
    this.name,
    this.age,
    this.zodiac,
    this.birthDate,
  });

  final String? name;
  final int? age;
  final String? zodiac;
  final DateTime? birthDate;

  bool get hasAny =>
      (name != null && name!.trim().isNotEmpty) ||
      (age != null && age! > 0) ||
      (zodiac != null && zodiac!.trim().isNotEmpty) ||
      birthDate != null;

  static FortuneFormPrefill? fromUser(AppUser? user) {
    if (user == null) return null;
    final name = user.displayName.trim();
    final zodiac = user.zodiac?.trim();
    return FortuneFormPrefill(
      name: name.isNotEmpty ? name : null,
      age: user.age != null && user.age! > 0 ? user.age : null,
      zodiac: zodiac != null && zodiac.isNotEmpty ? zodiac : null,
      birthDate: user.birthDate,
    );
  }

  static void logApplied() => debugPrint('FORTUNE_FORM_PREFILL_APPLIED');

  static void logSkippedCouple() =>
      debugPrint('FORTUNE_FORM_PREFILL_SKIPPED_COUPLE');

  void applyToNameController(TextEditingController controller) {
    if (name != null && name!.trim().isNotEmpty) {
      controller.text = name!.trim();
    }
  }

  void applyToAgeController(TextEditingController controller) {
    if (age != null && age! > 0) {
      controller.text = age.toString();
    }
  }

  String applyToZodiac(String current) {
    if (zodiac != null && burclar.contains(zodiac)) {
      return zodiac!;
    }
    return current;
  }

  void applyNameParts({
    required TextEditingController firstName,
    required TextEditingController lastName,
  }) {
    final full = name?.trim();
    if (full == null || full.isEmpty) return;
    final parts = full.split(RegExp(r'\s+'));
    firstName.text = parts.first;
    if (parts.length > 1) {
      lastName.text = parts.sublist(1).join(' ');
    }
  }
}
