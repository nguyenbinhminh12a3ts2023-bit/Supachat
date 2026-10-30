import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';

/// Provider quản lý các thao tác gửi tin nhắn và trạng thái chat
class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();

  bool _isSending = false;
  String? _errorMessage;

  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  /// Gửi tin nhắn văn bản thông thường
  Future<bool> sendTextMessage({
    required String receiverId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;

    _errorMessage = null;
    try {
      await _chatService.sendMessage(
        receiverId: receiverId,
        text: content.trim(),
        type: MessageType.text,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Tải ảnh lên Firebase Storage dạng Bytes và gửi tin nhắn hình ảnh (Hỗ trợ tốt Web & Mobile)
  Future<bool> sendImageBytes({
    required String receiverId,
    required Uint8List bytes,
  }) async {
    final senderId = _chatService.currentUserId;
    if (senderId == null) return false;

    final roomId = _chatService.getRoomId(senderId, receiverId);

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mediaUrl = await _storageService.uploadChatImageBytes(
        roomId: roomId,
        bytes: bytes,
      );

      await _chatService.sendMessage(
        receiverId: receiverId,
        text: '[Hình ảnh]',
        type: MessageType.image,
        mediaUrl: mediaUrl,
      );

      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Tải ảnh lên Firebase Storage và gửi tin nhắn hình ảnh
  Future<bool> sendImageMessage({
    required String receiverId,
    required File imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    return sendImageBytes(receiverId: receiverId, bytes: bytes);
  }

  /// Đánh dấu đã đọc
  Future<void> markAsRead(String roomId, String otherUserId) async {
    await _chatService.markMessagesAsRead(roomId, otherUserId);
  }

  /// Gửi tin nhắn thoại
  Future<bool> sendVoiceMessage({
    required String receiverId,
    required String audioUrl,
    required String duration,
  }) async {
    _isSending = true;
    notifyListeners();
    try {
      await _chatService.sendVoiceMessage(
        receiverId: receiverId,
        audioUrl: audioUrl,
        duration: duration,
      );
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSending = false;
      notifyListeners();
      return false;
    }
  }
}
