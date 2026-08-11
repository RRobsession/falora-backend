import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/characters/tombik_teyze.png').readAsBytesSync();
  final image = img.decodeImage(bytes)!;
  var minX = image.width, minY = image.height, maxX = 0, maxY = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a > 16) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  final contentW = maxX - minX + 1;
  final contentH = maxY - minY + 1;
  final cx = minX + contentW / 2;
  final canvasCx = image.width / 2;
  print('canvas: ${image.width}x${image.height}');
  print('content bounds: $minX,$minY - $maxX,$maxY (${contentW}x$contentH)');
  print('content center x: $cx, canvas center x: $canvasCx, offset: ${cx - canvasCx}');
}
