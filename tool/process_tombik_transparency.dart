import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Checkerboard / açık gri arka planı şeffaf PNG'ye çevirir.
void main() {
  const inputPath = 'assets/characters/tombik_teyze.png';
  final bytes = File(inputPath).readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    stderr.writeln('Görsel okunamadı: $inputPath');
    exit(1);
  }

  final rgba = image.convert(numChannels: 4);
  final w = rgba.width;
  final h = rgba.height;
  final visited = List<bool>.filled(w * h, false);
  final queue = <int>[];

  bool isBackground(int x, int y) {
    final p = rgba.getPixel(x, y);
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    if (maxC < 185) return false;
    if (maxC - minC > 32) return false;
    return true;
  }

  void enqueue(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final idx = y * w + x;
    if (visited[idx] || !isBackground(x, y)) return;
    visited[idx] = true;
    queue.add(idx);
  }

  for (var x = 0; x < w; x++) {
    enqueue(x, 0);
    enqueue(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    enqueue(0, y);
    enqueue(w - 1, y);
  }

  while (queue.isNotEmpty) {
    final idx = queue.removeLast();
    final x = idx % w;
    final y = idx ~/ w;
    rgba.setPixelRgba(x, y, 0, 0, 0, 0);
    enqueue(x + 1, y);
    enqueue(x - 1, y);
    enqueue(x, y + 1);
    enqueue(x, y - 1);
  }

  // Alt kesik kenarı yumuşat: bel hizasında alpha fade.
  for (var y = 0; y < h; y++) {
    final rowFade = y < (h * 0.68)
        ? 1.0
        : 1 - ((y - h * 0.68) / (h * 0.32)).clamp(0.0, 1.0);
    if (rowFade >= 1) continue;
    for (var x = 0; x < w; x++) {
      final p = rgba.getPixel(x, y);
      if (p.a == 0) continue;
      final alpha = (p.a * rowFade).round().clamp(0, 255);
      rgba.setPixelRgba(x, y, p.r, p.g, p.b, alpha);
    }
  }

  // Kenar yumuşatma: şeffaf olmayan piksellere komşu alpha düşür.
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final p = rgba.getPixel(x, y);
      if (p.a == 0) continue;
      var transparentNeighbors = 0;
      for (final o in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        if (rgba.getPixel(x + o[0], y + o[1]).a == 0) {
          transparentNeighbors++;
        }
      }
      if (transparentNeighbors >= 2 && p.a > 200) {
        rgba.setPixelRgba(x, y, p.r, p.g, p.b, (p.a * 0.88).round());
      }
    }
  }

  File(inputPath).writeAsBytesSync(img.encodePng(rgba));
  stdout.writeln('Şeffaf PNG kaydedildi: $inputPath (${w}x$h)');
}
