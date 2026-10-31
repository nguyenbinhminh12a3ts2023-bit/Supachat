import 'dart:typed_data';
import 'download_stub.dart'
    if (dart.library.html) 'download_web.dart' as dl;

/// Tiện ích tải hình ảnh về thiết bị (Web & Mobile)
class DownloadHelper {
  static Future<void> downloadImage(String url, {String? filename}) async {
    await dl.downloadFile(url, filename: filename);
  }

  static Future<void> downloadBytes(Uint8List bytes, {String? filename}) async {
    await dl.downloadBytes(bytes, filename: filename);
  }
}
