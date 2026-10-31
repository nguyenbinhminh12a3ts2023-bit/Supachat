// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class ClipboardImageHelper {
  static StreamSubscription? _pasteSubscription;

  /// Lắng nghe sự kiện dán ảnh từ Clipboard (Ctrl + V) trên Web
  static void listenForPastedImages(Function(Uint8List bytes) onImagePasted) {
    _pasteSubscription?.cancel();
    _pasteSubscription = html.document.onPaste.listen((event) {
      try {
        final items = event.clipboardData?.items;
        if (items != null) {
          final count = items.length ?? 0;
          for (int i = 0; i < count; i++) {
            final item = items[i];
            if (item.type != null && item.type!.startsWith('image/')) {
              event.preventDefault();
              final file = item.getAsFile();
              if (file != null) {
                final reader = html.FileReader();
                reader.readAsArrayBuffer(file);
                reader.onLoadEnd.listen((_) {
                  final result = reader.result;
                  if (result != null) {
                    final bytes = Uint8List.fromList(result as List<int>);
                    onImagePasted(bytes);
                  }
                });
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  static void dispose() {
    _pasteSubscription?.cancel();
    _pasteSubscription = null;
  }
}
