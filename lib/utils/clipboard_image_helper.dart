import 'dart:typed_data';
import 'clipboard_image_stub.dart'
    if (dart.library.html) 'clipboard_image_web.dart' as clip;

class ClipboardImageHelper {
  static void listenForPastedImages(Function(Uint8List bytes) onImagePasted) =>
      clip.ClipboardImageHelper.listenForPastedImages(onImagePasted);

  static void dispose() => clip.ClipboardImageHelper.dispose();
}

