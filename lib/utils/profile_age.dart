import 'package:cloud_firestore/cloud_firestore.dart';

/// Doğum tarihinden yaşı hesaplar.
int calculateAgeFromBirthDate(DateTime birthDate, {DateTime? reference}) {
  final today = reference ?? DateTime.now();
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}

int? displayAgeFromUserData(Map<String, dynamic> data) {
  final storedAge = (data['age'] as num?)?.toInt();
  final birthRaw = data['birthDate'];
  DateTime? birthDate;
  if (birthRaw is Timestamp) {
    birthDate = birthRaw.toDate();
  }
  if (birthDate != null) {
    return calculateAgeFromBirthDate(birthDate);
  }
  return storedAge;
}

String displayNameFromUserData(Map<String, dynamic> data) {
  final displayName = (data['displayName'] as String?)?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  return (data['name'] as String?)?.trim() ?? '';
}
