import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/models/manual_fortune_reader.dart';

class ManualReaderProfileService {
  ManualReaderProfileService._();
  static final instance = ManualReaderProfileService._();
  final _ref = FirebaseFirestore.instance.collection('manual_readers');

  Stream<List<ManualFortuneReader>> watch() =>
      _ref.where('active', isEqualTo: true).snapshots().map((snapshot) {
        final dynamicReaders = snapshot.docs
            .map((d) => ManualFortuneReader.fromMap(d.id, d.data()))
            .where((r) => r.name.trim().isNotEmpty)
            .toList();
        final ids = dynamicReaders.map((r) => r.id).toSet();
        return [
          ...manualFortuneReaders.where((r) => !ids.contains(r.id)),
          ...dynamicReaders,
        ];
      });

  Future<void> add({
    required String name,
    required String title,
    required String bio,
    String? gender,
    String? avatarBase64,
    required List<String> categoryIds,
  }) async {
    final id =
        '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
    await _ref.doc(id).set({
      'name': name.trim(),
      'title': title.trim(),
      'bio': bio.trim(),
      'gender': gender,
      'avatarBase64': avatarBase64,
      'categoryIds': categoryIds,
      'accentColor': 0xFF7A5C3E,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
