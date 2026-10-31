// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadFile(String url, {String? filename}) async {
  final name = filename ?? 'supachat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', name)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}

Future<void> downloadBytes(Uint8List bytes, {String? filename}) async {
  final name = filename ?? 'supachat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final blob = html.Blob([bytes], 'image/jpeg');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', name)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
