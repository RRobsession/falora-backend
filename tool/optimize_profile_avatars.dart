import 'dart:io';

import 'package:image/image.dart' as img;

/// İllüstrasyon avatarları 512x512 PNG olarak optimize eder.
void main() {
  const names = [
    'avatar_male_1', 'avatar_male_2', 'avatar_male_3',
    'avatar_male_4', 'avatar_male_5',
    'avatar_female_1', 'avatar_female_2', 'avatar_female_3',
    'avatar_female_4', 'avatar_female_5',
  ];

  final dir = Directory('assets/avatars');
  for (final name in names) {
    final path = '${dir.path}/$name.png';
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('MISSING: $path');
      continue;
    }
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      stderr.writeln('DECODE_FAIL: $path');
      continue;
    }
    final size = decoded.width < decoded.height ? decoded.width : decoded.height;
    final cropped = img.copyCrop(
      decoded,
      x: (decoded.width - size) ~/ 2,
      y: (decoded.height - size) ~/ 2,
      width: size,
      height: size,
    );
    final resized = img.copyResize(cropped, width: 512, height: 512);
    file.writeAsBytesSync(img.encodePng(resized, level: 6));
    stdout.writeln('OK $name.png (${file.lengthSync()} bytes)');
  }
}
