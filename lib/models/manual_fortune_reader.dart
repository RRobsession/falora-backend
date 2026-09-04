import 'dart:convert';
import 'dart:typed_data';
import 'package:falora/models/fortune_models.dart';
import 'package:flutter/material.dart';

const defaultManualReaderCategoryIds = <String>[
  'kahve',
  'bakla',
  'tarot',
];

/// Admin tarafından cevaplanan premium manuel yorumcu.
class ManualFortuneReader {
  const ManualFortuneReader({
    required this.id,
    required this.name,
    required this.title,
    required this.bio,
    required this.accentColor,
    required this.avatarAsset,
    this.avatarBase64,
    this.categoryIds = defaultManualReaderCategoryIds,
  });

  final String id;
  final String name;
  final String title;
  final String bio;
  final Color accentColor;
  final String avatarAsset;
  final String? avatarBase64;
  final List<String> categoryIds;

  bool supports(FortuneCategory category) => categoryIds.contains(category.name);

  Uint8List? get avatarBytes {
    final value = avatarBase64;
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  factory ManualFortuneReader.fromMap(String id, Map<String, dynamic> data) =>
      ManualFortuneReader(
        id: id,
        name: '${data['name'] ?? ''}',
        title: '${data['title'] ?? ''}',
        bio: '${data['bio'] ?? ''}',
        accentColor: Color(
          (data['accentColor'] as num?)?.toInt() ?? 0xFF7A5C3E,
        ),
        avatarAsset: '${data['avatarAsset'] ?? ''}',
        avatarBase64: data['avatarBase64']?.toString(),
        categoryIds: (data['categoryIds'] as List?)
                ?.map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .toList() ??
            defaultManualReaderCategoryIds,
      );
}

const manualFortuneReaders = <ManualFortuneReader>[
  ManualFortuneReader(
    id: 'serdar',
    name: 'Serdar',
    title: 'Sezgisel Yorumcu',
    bio:
        'Genç ve modern bakış açısıyla kişisel yorum sunar. Sorularınıza detaylı ve özenli yaklaşır.',
    accentColor: Color(0xFF5C4228),
    avatarAsset: 'assets/avatars/serdar.png',
  ),
  ManualFortuneReader(
    id: 'hatice',
    name: 'Hatice',
    title: 'Bilge Yorumcu',
    bio:
        'Tecrübeli ve sezgisel yaklaşımıyla derinlemesine yorum yapar. Sembolleri ve işaretleri dikkatle değerlendirir.',
    accentColor: Color(0xFF7A5C3E),
    avatarAsset: 'assets/avatars/hatice.png',
  ),
];

ManualFortuneReader? manualReaderById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final r in manualFortuneReaders) {
    if (r.id == id) return r;
  }
  return null;
}
