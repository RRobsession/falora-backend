import 'dart:io';

import 'package:falora/config/category_fortune_config.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Fal formlarında son seçilen medeni durumu cihazda saklar.
class MaritalStatusPreference {
  MaritalStatusPreference._();

  static final MaritalStatusPreference instance = MaritalStatusPreference._();

  static const _fileName = 'last_marital_status.txt';

  String? _saved;

  String get current {
    if (_saved != null && maritalStatusOptions.contains(_saved)) {
      return _saved!;
    }
    return maritalStatusOptions.first;
  }

  Future<void> load() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fileName');
      if (!await file.exists()) return;
      final value = (await file.readAsString()).trim();
      if (maritalStatusOptions.contains(value)) {
        _saved = value;
      }
    } catch (e) {
      debugPrint('MARITAL_STATUS_PREF_LOAD_FAIL: $e');
    }
  }

  Future<void> save(String value) async {
    if (!maritalStatusOptions.contains(value)) return;
    _saved = value;
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsString(value);
    } catch (e) {
      debugPrint('MARITAL_STATUS_PREF_SAVE_FAIL: $e');
    }
  }
}
