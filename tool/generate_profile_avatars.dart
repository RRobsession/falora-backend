import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 10 farklı premium profil avatarı üretir (erkek/kadın).
void main() {
  final outDir = Directory('assets/avatars');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final maleStyles = <_AvatarStyle>[
    _AvatarStyle(
      skin: (242, 210, 188),
      hair: (45, 35, 28),
      shirt: (52, 98, 175),
      bgTop: (232, 218, 196),
      bgBottom: (210, 185, 150),
      hairStyle: _HairStyle.shortCrop,
    ),
    _AvatarStyle(
      skin: (230, 195, 165),
      hair: (28, 22, 18),
      shirt: (34, 120, 145),
      bgTop: (225, 212, 190),
      bgBottom: (195, 170, 135),
      hairStyle: _HairStyle.sidePart,
    ),
    _AvatarStyle(
      skin: (248, 220, 200),
      hair: (120, 85, 55),
      shirt: (70, 88, 132),
      bgTop: (240, 228, 210),
      bgBottom: (215, 195, 165),
      hairStyle: _HairStyle.curlyShort,
    ),
    _AvatarStyle(
      skin: (210, 175, 145),
      hair: (18, 18, 22),
      shirt: (88, 72, 118),
      bgTop: (228, 215, 195),
      bgBottom: (190, 165, 130),
      hairStyle: _HairStyle.buzz,
    ),
    _AvatarStyle(
      skin: (235, 200, 175),
      hair: (75, 55, 40),
      shirt: (45, 76, 110),
      bgTop: (235, 220, 200),
      bgBottom: (200, 178, 145),
      hairStyle: _HairStyle.wavyTop,
    ),
  ];

  final femaleStyles = <_AvatarStyle>[
    _AvatarStyle(
      skin: (252, 218, 198),
      hair: (140, 70, 45),
      shirt: (196, 92, 122),
      bgTop: (245, 225, 215),
      bgBottom: (220, 185, 170),
      hairStyle: _HairStyle.longStraight,
    ),
    _AvatarStyle(
      skin: (238, 195, 170),
      hair: (30, 25, 22),
      shirt: (210, 118, 88),
      bgTop: (240, 220, 205),
      bgBottom: (210, 180, 155),
      hairStyle: _HairStyle.bob,
    ),
    _AvatarStyle(
      skin: (245, 210, 185),
      hair: (180, 130, 70),
      shirt: (175, 82, 140),
      bgTop: (242, 225, 210),
      bgBottom: (215, 190, 165),
      hairStyle: _HairStyle.wavyLong,
    ),
    _AvatarStyle(
      skin: (220, 180, 155),
      hair: (55, 40, 32),
      shirt: (220, 105, 130),
      bgTop: (235, 215, 200),
      bgBottom: (200, 170, 145),
      hairStyle: _HairStyle.ponytail,
    ),
    _AvatarStyle(
      skin: (250, 225, 205),
      hair: (95, 65, 50),
      shirt: (165, 70, 115),
      bgTop: (248, 230, 218),
      bgBottom: (218, 188, 168),
      hairStyle: _HairStyle.bun,
    ),
  ];

  for (var i = 0; i < 5; i++) {
    _writeProfileAvatar(
      '${outDir.path}/avatar_male_${i + 1}.png',
      maleStyles[i],
      isFemale: false,
    );
    _writeProfileAvatar(
      '${outDir.path}/avatar_female_${i + 1}.png',
      femaleStyles[i],
      isFemale: true,
    );
  }

  stdout.writeln('Generated 10 profile avatars in assets/avatars/');
}

enum _HairStyle {
  shortCrop,
  sidePart,
  curlyShort,
  buzz,
  wavyTop,
  longStraight,
  bob,
  wavyLong,
  ponytail,
  bun,
}

class _AvatarStyle {
  const _AvatarStyle({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.bgTop,
    required this.bgBottom,
    required this.hairStyle,
  });

  final (int, int, int) skin;
  final (int, int, int) hair;
  final (int, int, int) shirt;
  final (int, int, int) bgTop;
  final (int, int, int) bgBottom;
  final _HairStyle hairStyle;
}

void _writeProfileAvatar(String path, _AvatarStyle style, {required bool isFemale}) {
  const size = 512;
  final image = img.Image(width: size, height: size);

  for (var y = 0; y < size; y++) {
    final t = y / (size - 1);
    final r = _lerp(style.bgTop.$1, style.bgBottom.$1, t);
    final g = _lerp(style.bgTop.$2, style.bgBottom.$2, t);
    final b = _lerp(style.bgTop.$3, style.bgBottom.$3, t);
    for (var x = 0; x < size; x++) {
      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }

  final cx = size ~/ 2;
  final shirtY = (size * 0.62).round();
  _fillEllipse(image, cx, shirtY + 90, 155, 120, _rgb(style.shirt));
  _fillEllipse(image, cx, shirtY, 130, 95, _rgb(style.shirt));

  final neckY = (size * 0.52).round();
  _fillEllipse(image, cx, neckY + 20, 42, 35, _rgb(style.skin));

  final faceY = (size * 0.38).round();
  _fillCircle(image, cx, faceY, 88, _rgb(style.skin));

  _drawHair(image, cx, faceY, style);

  final eyeY = faceY - 8;
  _fillCircle(image, cx - 30, eyeY, 7, img.ColorRgb8(255, 255, 255));
  _fillCircle(image, cx + 30, eyeY, 7, img.ColorRgb8(255, 255, 255));
  _fillCircle(image, cx - 30, eyeY, 4, img.ColorRgb8(50, 38, 30));
  _fillCircle(image, cx + 30, eyeY, 4, img.ColorRgb8(50, 38, 30));

  _fillEllipse(image, cx, faceY + 28, 12, 6, img.ColorRgb8(195, 120, 110));

  _fillArcSmile(image, cx, faceY + 42, 22, img.ColorRgb8(140, 80, 75));

  if (isFemale) {
    _fillCircle(image, cx - 52, faceY + 18, 10, img.ColorRgb8(220, 140, 130));
    _fillCircle(image, cx + 52, faceY + 18, 10, img.ColorRgb8(220, 140, 130));
  }

  final border = img.ColorRgb8(180, 150, 110);
  _strokeCircle(image, cx, faceY, 88, border, 2);

  File(path).writeAsBytesSync(Uint8List.fromList(img.encodePng(image)));
}

void _drawHair(img.Image image, int cx, int faceY, _AvatarStyle style) {
  final hair = _rgb(style.hair);
  switch (style.hairStyle) {
    case _HairStyle.shortCrop:
      _fillEllipse(image, cx, faceY - 55, 95, 55, hair);
      _fillRect(image, cx - 95, faceY - 80, cx + 95, faceY - 20, hair);
    case _HairStyle.sidePart:
      _fillEllipse(image, cx - 8, faceY - 58, 98, 58, hair);
      _fillRect(image, cx - 100, faceY - 85, cx + 90, faceY - 25, hair);
    case _HairStyle.curlyShort:
      for (var i = -3; i <= 3; i++) {
        _fillCircle(image, cx + i * 22, faceY - 70, 28, hair);
      }
    case _HairStyle.buzz:
      _fillCircle(image, cx, faceY - 50, 82, hair);
    case _HairStyle.wavyTop:
      _fillEllipse(image, cx, faceY - 60, 100, 62, hair);
      _fillEllipse(image, cx - 40, faceY - 75, 35, 30, hair);
      _fillEllipse(image, cx + 40, faceY - 75, 35, 30, hair);
    case _HairStyle.longStraight:
      _fillEllipse(image, cx, faceY - 60, 100, 60, hair);
      _fillRect(image, cx - 105, faceY - 90, cx - 55, faceY + 120, hair);
      _fillRect(image, cx + 55, faceY - 90, cx + 105, faceY + 120, hair);
    case _HairStyle.bob:
      _fillEllipse(image, cx, faceY - 58, 102, 62, hair);
      _fillEllipse(image, cx - 95, faceY + 10, 35, 70, hair);
      _fillEllipse(image, cx + 95, faceY + 10, 35, 70, hair);
    case _HairStyle.wavyLong:
      for (var side = -1; side <= 1; side += 2) {
        for (var j = 0; j < 4; j++) {
          _fillCircle(
            image,
            cx + side * (70 + j * 8),
            faceY - 50 + j * 45,
            32,
            hair,
          );
        }
      }
      _fillEllipse(image, cx, faceY - 62, 105, 65, hair);
    case _HairStyle.ponytail:
      _fillEllipse(image, cx, faceY - 58, 95, 55, hair);
      _fillEllipse(image, cx, faceY - 110, 28, 45, hair);
    case _HairStyle.bun:
      _fillEllipse(image, cx, faceY - 58, 95, 55, hair);
      _fillCircle(image, cx, faceY - 105, 38, hair);
  }
}

img.ColorRgb8 _rgb((int, int, int) c) => img.ColorRgb8(c.$1, c.$2, c.$3);

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

void _fillCircle(img.Image image, int cx, int cy, int radius, img.Color color) {
  for (var y = cy - radius; y <= cy + radius; y++) {
    for (var x = cx - radius; x <= cx + radius; x++) {
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= radius * radius) {
        if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

void _fillEllipse(
  img.Image image,
  int cx,
  int cy,
  int rx,
  int ry,
  img.Color color,
) {
  for (var y = cy - ry; y <= cy + ry; y++) {
    for (var x = cx - rx; x <= cx + rx; x++) {
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1) {
        if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

void _fillRect(img.Image image, int x1, int y1, int x2, int y2, img.Color color) {
  for (var y = y1; y <= y2; y++) {
    for (var x = x1; x <= x2; x++) {
      if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
        image.setPixel(x, y, color);
      }
    }
  }
}

void _strokeCircle(
  img.Image image,
  int cx,
  int cy,
  int radius,
  img.Color color,
  int width,
) {
  for (var angle = 0.0; angle < 2 * math.pi; angle += 0.02) {
    for (var w = 0; w < width; w++) {
      final r = radius - w;
      final x = (cx + r * math.cos(angle)).round();
      final y = (cy + r * math.sin(angle)).round();
      if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
        image.setPixel(x, y, color);
      }
    }
  }
}

void _fillArcSmile(img.Image image, int cx, int cy, int radius, img.Color color) {
  for (var angle = 0.15; angle < math.pi - 0.15; angle += 0.04) {
    final x = (cx + radius * math.cos(angle)).round();
    final y = (cy + radius * math.sin(angle) * 0.5).round();
    if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
      image.setPixel(x, y, color);
      if (x + 1 < image.width) image.setPixel(x + 1, y, color);
    }
  }
}
