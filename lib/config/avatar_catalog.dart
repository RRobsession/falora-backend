class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.assetPath,
    required this.gender,
  });

  final String id;
  final String assetPath;
  final AvatarGender gender;
}

enum AvatarGender { male, female }

const presetAvatars = <AvatarOption>[
  AvatarOption(
    id: 'avatar_male_1',
    assetPath: 'assets/avatars/avatar_male_1.png',
    gender: AvatarGender.male,
  ),
  AvatarOption(
    id: 'avatar_male_2',
    assetPath: 'assets/avatars/avatar_male_2.png',
    gender: AvatarGender.male,
  ),
  AvatarOption(
    id: 'avatar_male_3',
    assetPath: 'assets/avatars/avatar_male_3.png',
    gender: AvatarGender.male,
  ),
  AvatarOption(
    id: 'avatar_male_4',
    assetPath: 'assets/avatars/avatar_male_4.png',
    gender: AvatarGender.male,
  ),
  AvatarOption(
    id: 'avatar_male_5',
    assetPath: 'assets/avatars/avatar_male_5.png',
    gender: AvatarGender.male,
  ),
  AvatarOption(
    id: 'avatar_female_1',
    assetPath: 'assets/avatars/avatar_female_1.png',
    gender: AvatarGender.female,
  ),
  AvatarOption(
    id: 'avatar_female_2',
    assetPath: 'assets/avatars/avatar_female_2.png',
    gender: AvatarGender.female,
  ),
  AvatarOption(
    id: 'avatar_female_3',
    assetPath: 'assets/avatars/avatar_female_3.png',
    gender: AvatarGender.female,
  ),
  AvatarOption(
    id: 'avatar_female_4',
    assetPath: 'assets/avatars/avatar_female_4.png',
    gender: AvatarGender.female,
  ),
  AvatarOption(
    id: 'avatar_female_5',
    assetPath: 'assets/avatars/avatar_female_5.png',
    gender: AvatarGender.female,
  ),
];

AvatarOption? avatarOptionByAsset(String? assetPath) {
  if (assetPath == null || assetPath.trim().isEmpty) return null;
  for (final option in presetAvatars) {
    if (option.assetPath == assetPath || option.id == assetPath) return option;
  }
  return null;
}

String? resolvePresetAvatarAssetPath(String? avatarAsset) {
  final trimmed = avatarAsset?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('custom:')) return null;
  final normalized = normalizeStoredAvatarAsset(trimmed);
  if (avatarOptionByAsset(normalized) != null) return normalized;
  if (normalized.startsWith('assets/avatars/avatar_')) return normalized;
  return null;
}

String normalizeStoredAvatarAsset(String? avatarAsset) {
  if (avatarAsset == null || avatarAsset.trim().isEmpty) {
    return '';
  }
  final trimmed = avatarAsset.trim();
  if (trimmed.startsWith('custom:')) return trimmed;
  const legacyMap = <String, String>{
    'assets/avatars/male_01.png': 'assets/avatars/avatar_male_1.png',
    'assets/avatars/male_02.png': 'assets/avatars/avatar_male_2.png',
    'assets/avatars/male_03.png': 'assets/avatars/avatar_male_3.png',
    'assets/avatars/male_04.png': 'assets/avatars/avatar_male_4.png',
    'assets/avatars/male_05.png': 'assets/avatars/avatar_male_5.png',
    'assets/avatars/female_01.png': 'assets/avatars/avatar_female_1.png',
    'assets/avatars/female_02.png': 'assets/avatars/avatar_female_2.png',
    'assets/avatars/female_03.png': 'assets/avatars/avatar_female_3.png',
    'assets/avatars/female_04.png': 'assets/avatars/avatar_female_4.png',
    'assets/avatars/female_05.png': 'assets/avatars/avatar_female_5.png',
  };
  return legacyMap[trimmed] ?? trimmed;
}

List<String> get allPresetAvatarAssetPaths =>
    presetAvatars.map((a) => a.assetPath).toList();
