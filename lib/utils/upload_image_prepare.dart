import 'dart:convert';

import 'package:falora/picked_image.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Vision API'ye giden görselleri küçültür — token ve süreyi düşürür.
const _maxEdge = 1280;
const _jpegQuality = 82;
const _skipBelowBytes = 350 * 1024;

/// Sorun bildirimi — UI'yi dondurmamak için daha agresif sıkıştırma.
const problemReportMaxEdge = 960;
const problemReportJpegQuality = 70;
const problemReportSkipBelowBytes = 80 * 1024;
const problemReportMaxImagePayloadChars = 450 * 1024;

/// Serdar/Hatice kahve falı — netlik koruyarak Firestore limitine sığdırır.
const manualFortuneMaxEdge = 1600;
const manualFortuneJpegQuality = 85;
const manualFortuneSkipBelowBytes = 400 * 1024;
const manualFortuneFallbackMaxEdge = 1280;
const manualFortuneFallbackJpegQuality = 75;

/// imageInfo base64 alanları için güvenli üst sınır (belge ~1 MB).
const manualFortuneMaxImagePayloadChars = 900 * 1024;

class ImagePrepareOptions {
  const ImagePrepareOptions({
    required this.maxEdge,
    required this.jpegQuality,
    required this.skipBelowBytes,
  });

  final int maxEdge;
  final int jpegQuality;
  final int skipBelowBytes;
}

const problemReportImagePrepareOptions = ImagePrepareOptions(
  maxEdge: problemReportMaxEdge,
  jpegQuality: problemReportJpegQuality,
  skipBelowBytes: problemReportSkipBelowBytes,
);

const manualFortuneImagePrepareOptions = ImagePrepareOptions(
  maxEdge: manualFortuneMaxEdge,
  jpegQuality: manualFortuneJpegQuality,
  skipBelowBytes: manualFortuneSkipBelowBytes,
);

const manualFortuneImagePrepareFallbackOptions = ImagePrepareOptions(
  maxEdge: manualFortuneFallbackMaxEdge,
  jpegQuality: manualFortuneFallbackJpegQuality,
  skipBelowBytes: 0,
);

class _PrepareImageArgs {
  const _PrepareImageArgs({
    required this.name,
    required this.bytes,
    required this.maxEdge,
    required this.jpegQuality,
    required this.skipBelowBytes,
  });

  final String name;
  final Uint8List bytes;
  final int maxEdge;
  final int jpegQuality;
  final int skipBelowBytes;
}

class _PreparedImageResult {
  const _PreparedImageResult({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

String _jpegName(String original) {
  final dot = original.lastIndexOf('.');
  final base = dot > 0 ? original.substring(0, dot) : original;
  return '$base.jpg';
}

img.Image _resizeIfNeeded(img.Image decoded, int maxEdge) {
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest <= maxEdge) return decoded;
  if (decoded.width >= decoded.height) {
    return img.copyResize(decoded, width: maxEdge);
  }
  return img.copyResize(decoded, height: maxEdge);
}

/// Isolate / compute için top-level (UI thread'i bloklamaz).
_PreparedImageResult _prepareImageIsolate(_PrepareImageArgs args) {
  if (args.bytes.isEmpty) {
    return _PreparedImageResult(name: args.name, bytes: args.bytes);
  }
  try {
    final decoded = img.decodeImage(args.bytes);
    if (decoded == null) {
      return _PreparedImageResult(name: args.name, bytes: args.bytes);
    }

    final needsResize =
        decoded.width > args.maxEdge || decoded.height > args.maxEdge;
    if (!needsResize && args.bytes.length <= args.skipBelowBytes) {
      return _PreparedImageResult(name: args.name, bytes: args.bytes);
    }

    final resized =
        needsResize ? _resizeIfNeeded(decoded, args.maxEdge) : decoded;
    final jpegBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: args.jpegQuality),
    );
    return _PreparedImageResult(name: _jpegName(args.name), bytes: jpegBytes);
  } catch (_) {
    return _PreparedImageResult(name: args.name, bytes: args.bytes);
  }
}

Future<PickedImage> prepareImageWithOptions(
  PickedImage image,
  ImagePrepareOptions options,
) async {
  if (image.bytes.isEmpty) return image;

  final result = await compute(
    _prepareImageIsolate,
    _PrepareImageArgs(
      name: image.name,
      bytes: image.bytes,
      maxEdge: options.maxEdge,
      jpegQuality: options.jpegQuality,
      skipBelowBytes: options.skipBelowBytes,
    ),
  );

  if (kDebugMode) {
    debugPrint(
      'IMAGE PREPARE ${image.name}: '
      '${image.bytes.length} -> ${result.bytes.length} bytes '
      '(edge=${options.maxEdge}, q=${options.jpegQuality})',
    );
  }

  return PickedImage(name: result.name, bytes: result.bytes);
}

Future<PickedImage> prepareImageForUpload(PickedImage image) =>
    prepareImageWithOptions(
      image,
      const ImagePrepareOptions(
        maxEdge: _maxEdge,
        jpegQuality: _jpegQuality,
        skipBelowBytes: _skipBelowBytes,
      ),
    );

/// Sorun bildirimi ekran görüntüsü — daha küçük, arka planda hazırlanır.
Future<PickedImage> prepareProblemReportImageForUpload(PickedImage image) =>
    prepareImageWithOptions(image, problemReportImagePrepareOptions);

Future<List<PickedImage>> prepareImagesWithOptions(
  List<PickedImage> images,
  ImagePrepareOptions options,
) async {
  final prepared = <PickedImage>[];
  for (final image in images) {
    prepared.add(await prepareImageWithOptions(image, options));
  }
  return prepared;
}

Future<List<PickedImage>> prepareImagesForUpload(
  List<PickedImage> images,
) async {
  return prepareImagesWithOptions(
    images,
    const ImagePrepareOptions(
      maxEdge: _maxEdge,
      jpegQuality: _jpegQuality,
      skipBelowBytes: _skipBelowBytes,
    ),
  );
}

int estimateBase64PayloadChars(List<PickedImage> images) {
  if (images.isEmpty) return 0;
  var total = 2; // []
  for (var i = 0; i < images.length; i++) {
    if (i > 0) total += 1;
    // Yaklaşık: {"name":"..","mime":"image/jpeg","base64":"..."}
    total += 48 + images[i].name.length;
    total += ((images[i].bytes.length + 2) ~/ 3) * 4;
  }
  return total;
}

int estimateManualFortuneImagePayloadChars(List<PickedImage> images) {
  if (images.isEmpty) return 0;
  return estimateBase64PayloadChars(images);
}

/// Kahve falı fotoğrafları: 1600px/%85, gerekirse 1280px/%75 ikinci tur.
Future<List<PickedImage>> prepareManualFortuneImagesForUpload(
  List<PickedImage> images,
) async {
  if (images.isEmpty) return images;

  var prepared =
      await prepareImagesWithOptions(images, manualFortuneImagePrepareOptions);
  var payloadChars = estimateManualFortuneImagePayloadChars(prepared);

  if (payloadChars > manualFortuneMaxImagePayloadChars) {
    if (kDebugMode) {
      debugPrint(
        'MANUAL IMAGE PREPARE fallback: payload=${payloadChars ~/ 1024}KB',
      );
    }
    prepared = await prepareImagesWithOptions(
      images,
      manualFortuneImagePrepareFallbackOptions,
    );
    payloadChars = estimateManualFortuneImagePayloadChars(prepared);
  }

  if (kDebugMode) {
    debugPrint(
      'MANUAL IMAGE PREPARE done: ${prepared.length} images, '
      'payload=${payloadChars ~/ 1024}KB',
    );
  }

  return prepared;
}

bool manualFortuneImagesFitFirestore(List<PickedImage> images) =>
    estimateManualFortuneImagePayloadChars(images) <=
    manualFortuneMaxImagePayloadChars;

class _EncodeImageArgs {
  const _EncodeImageArgs({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Map<String, String> _encodeImageIsolate(_EncodeImageArgs args) {
  final lower = args.name.toLowerCase();
  final mime = lower.endsWith('.png')
      ? 'image/png'
      : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
  return {
    'name': args.name,
    'mime': mime,
    'base64': base64Encode(args.bytes),
  };
}

/// base64Encode büyük buffer'da UI'yi dondurmasın diye isolate'de çalışır.
Future<Map<String, String>> encodeImageForFirestorePayload(
  PickedImage image,
) {
  return compute(
    _encodeImageIsolate,
    _EncodeImageArgs(name: image.name, bytes: image.bytes),
  );
}
