import 'package:flutter/material.dart';

/// Admin tarafından cevaplanan premium manuel yorumcu.
class ManualFortuneReader {
  const ManualFortuneReader({
    required this.id,
    required this.name,
    required this.title,
    required this.bio,
    required this.accentColor,
    required this.avatarAsset,
  });

  final String id;
  final String name;
  final String title;
  final String bio;
  final Color accentColor;
  final String avatarAsset;
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
