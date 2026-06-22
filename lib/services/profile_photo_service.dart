import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Profil fotoğrafını cihazda yerel olarak saklar.
class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  Future<File> _photoFile(String userId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/profile_$userId.jpg');
  }

  Future<Uint8List?> loadPhotoBytes(String userId) async {
    if (kIsWeb) return null;
    try {
      final file = await _photoFile(userId);
      if (!await file.exists()) return null;
      return file.readAsBytes();
    } catch (e) {
      debugPrint('PROFILE PHOTO LOAD ERROR: $e');
      return null;
    }
  }

  Future<void> savePhoto(String userId, Uint8List bytes) async {
    if (kIsWeb) return;
    try {
      final file = await _photoFile(userId);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('PROFILE PHOTO SAVE ERROR: $e');
      rethrow;
    }
  }

  Future<void> deletePhoto(String userId) async {
    if (kIsWeb) return;
    try {
      final file = await _photoFile(userId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('PROFILE PHOTO DELETE ERROR: $e');
      rethrow;
    }
  }
}
