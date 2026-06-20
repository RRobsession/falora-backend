import 'dart:typed_data';

class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
