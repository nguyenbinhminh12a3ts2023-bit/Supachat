import 'dart:typed_data';

Future<void> downloadFile(String url, {String? filename}) async {
  // No-op for non-web environments without native file picker
}

Future<void> downloadBytes(Uint8List bytes, {String? filename}) async {
  // No-op for non-web environments without native file picker
}
