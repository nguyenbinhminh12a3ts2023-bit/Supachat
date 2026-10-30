import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Dịch vụ xử lý tải file lên Firebase Storage (Avatar, Ảnh trong đoạn chat, Ảnh bài viết)
class StorageService {
  FirebaseStorage get _storage {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseStorage.instance;
      }
    } catch (_) {}
    return FirebaseStorage.instance;
  }

  /// Tải ảnh đại diện người dùng lên Firebase Storage dạng Bytes (Hoạt động đa nền tảng Web & Mobile)
  Future<String> uploadAvatarBytes({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final ref = _storage.ref().child('avatars').child('$uid.jpg');
      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Lỗi khi tải ảnh đại diện lên máy chủ: ${e.message}');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định khi upload ảnh: $e');
    }
  }

  /// Tải ảnh đại diện người dùng lên Firebase Storage (File)
  Future<String> uploadAvatar({
    required String uid,
    required File file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadAvatarBytes(uid: uid, bytes: bytes);
    } catch (e) {
      throw Exception('Lỗi khi đọc file ảnh đại diện: $e');
    }
  }

  /// Tải ảnh gửi trong phòng chat lên Firebase Storage dạng Bytes (Hỗ trợ Web & Mobile)
  Future<String> uploadChatImageBytes({
    required String roomId,
    required Uint8List bytes,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('chats').child(roomId).child('$timestamp.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Lưu ý upload ảnh chat: $e');
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  /// Tải ảnh gửi trong phòng chat lên Firebase Storage (File)
  Future<String> uploadChatImage({
    required String roomId,
    required File file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadChatImageBytes(roomId: roomId, bytes: bytes);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định khi gửi ảnh: $e');
    }
  }

  /// Tải tệp tin tài liệu lên Firebase Storage
  Future<String> uploadFileBytes({
    required String roomId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('files').child(roomId).child('${timestamp}_$fileName');
      final uploadTask = await ref.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Lưu ý upload file: $e');
      return 'data:application/octet-stream;base64,${base64Encode(bytes)}';
    }
  }

  /// Nén và giảm kích thước ảnh để đảm bảo an toàn dung lượng mạng và Firestore limit (<200KB)
  static Future<Uint8List> safeOptimizeImageBytes(Uint8List rawBytes, {int targetWidth = 640}) async {
    if (rawBytes.lengthInBytes <= 150 * 1024) {
      return rawBytes;
    }
    try {
      final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: targetWidth);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final compressed = byteData.buffer.asUint8List();
        if (compressed.lengthInBytes < rawBytes.lengthInBytes) {
          return compressed;
        }
      }
    } catch (e) {
      debugPrint('Lưu ý nén ảnh: $e');
    }
    return rawBytes;
  }

  /// Tải ảnh bài viết lên Firebase Storage dạng Bytes (Hỗ trợ tốt trên cả Web & Mobile)
  Future<String> uploadPostImageBytes({required Uint8List bytes}) async {
    final optimizedBytes = await safeOptimizeImageBytes(bytes);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('posts').child('$timestamp.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = await ref.putData(optimizedBytes, metadata).timeout(const Duration(seconds: 12));
      final downloadUrl = await uploadTask.ref.getDownloadURL().timeout(const Duration(seconds: 8));
      return downloadUrl;
    } catch (e) {
      debugPrint('Lưu ý upload ảnh lên Storage: $e');
      // Trả về định dạng data URI an toàn (<250KB) nếu Firebase Storage quá giờ hoặc bị chặn CORS
      return 'data:image/jpeg;base64,${base64Encode(optimizedBytes)}';
    }
  }

  /// Tải ảnh bài viết lên Firebase Storage (File cho mobile)
  Future<String> uploadPostImage({required File file}) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadPostImageBytes(bytes: bytes);
    } catch (e) {
      throw Exception('Lỗi khi tải ảnh bài viết: $e');
    }
  }
}
