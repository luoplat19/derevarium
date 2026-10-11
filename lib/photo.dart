import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List compressTreePhoto(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final oriented = img.bakeOrientation(decoded);
    final longest = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longest > 1000
        ? img.copyResize(
            oriented,
            width: (oriented.width * 1000 / longest).round().clamp(1, 1000),
            height: (oriented.height * 1000 / longest).round().clamp(1, 1000),
          )
        : oriented;
    return img.encodeJpg(resized, quality: 70);
  } catch (_) {
    // Preserve the selected photo if its format cannot be decoded.
    return bytes;
  }
}
