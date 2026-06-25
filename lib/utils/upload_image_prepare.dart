import 'package:falora/picked_image.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Vision API'ye giden görselleri küçültür — token ve süreyi düşürür.
const _maxEdge = 1280;
const _jpegQuality = 82;
const _skipBelowBytes = 350 * 1024;

String _jpegName(String original) {
  final dot = original.lastIndexOf('.');
  final base = dot > 0 ? original.substring(0, dot) : original;
  return '$base.jpg';
}

img.Image _resizeIfNeeded(img.Image decoded) {
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest <= _maxEdge) return decoded;
  if (decoded.width >= decoded.height) {
    return img.copyResize(decoded, width: _maxEdge);
  }
  return img.copyResize(decoded, height: _maxEdge);
}

Future<PickedImage> prepareImageForUpload(PickedImage image) async {
  if (image.bytes.isEmpty) return image;
  try {
    final decoded = img.decodeImage(image.bytes);
    if (decoded == null) return image;

    final needsResize = decoded.width > _maxEdge || decoded.height > _maxEdge;
    if (!needsResize && image.bytes.length <= _skipBelowBytes) {
      return image;
    }

    final resized = needsResize ? _resizeIfNeeded(decoded) : decoded;
    final jpegBytes =
        Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));

    if (kDebugMode) {
      debugPrint(
        'IMAGE PREPARE ${image.name}: '
        '${image.bytes.length} -> ${jpegBytes.length} bytes',
      );
    }

    return PickedImage(name: _jpegName(image.name), bytes: jpegBytes);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('IMAGE PREPARE SKIP ${image.name}: $e');
    }
    return image;
  }
}

Future<List<PickedImage>> prepareImagesForUpload(
  List<PickedImage> images,
) async {
  final prepared = <PickedImage>[];
  for (final image in images) {
    prepared.add(await prepareImageForUpload(image));
  }
  return prepared;
}
