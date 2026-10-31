import 'package:cloud_firestore/cloud_firestore.dart';

/// Loại tin nhắn: văn bản (text), hình ảnh (image), tệp tin (file), sticker, vị trí (location), cảnh báo chụp màn hình, bàn phím bảo mật, cuộc gọi thoại, tin nhắn thoại (voice)
enum MessageType {
  text,
  image,
  file,
  sticker,
  location,
  voice,
  screenshotAlert,
  secureKeypadNotice,
  callNotice,
}

/// Model biểu diễn một tin nhắn trong sub-collection messages của phòng chat
class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text; // Trường text nội dung hoặc tên địa điểm
  final MessageType type;
  final String? mediaUrl;
  final String? fileName;
  final String? fileSize;
  final DateTime timestamp;
  final bool isSeen;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    required this.timestamp,
    this.isSeen = false,
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  /// Getter alias tương thích với giao diện cũ
  String get content => text;

  static String _typeToString(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'image';
      case MessageType.file:
        return 'file';
      case MessageType.sticker:
        return 'sticker';
      case MessageType.location:
        return 'location';
      case MessageType.voice:
        return 'voice';
      case MessageType.screenshotAlert:
        return 'screenshotAlert';
      case MessageType.secureKeypadNotice:
        return 'secureKeypadNotice';
      case MessageType.callNotice:
        return 'callNotice';
      case MessageType.text:
        return 'text';
    }
  }

  static MessageType _stringToType(String? val) {
    switch (val) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'sticker':
        return MessageType.sticker;
      case 'location':
        return MessageType.location;
      case 'voice':
        return MessageType.voice;
      case 'screenshotAlert':
        return MessageType.screenshotAlert;
      case 'secureKeypadNotice':
        return MessageType.secureKeypadNotice;
      case 'callNotice':
        return MessageType.callNotice;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  /// Chuyển đổi sang Map để lưu trên Firestore với FieldValue.serverTimestamp()
  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'content': text,
      'type': _typeToString(type),
      'mediaUrl': mediaUrl ?? '',
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      'timestamp': useServerTimestamp ? FieldValue.serverTimestamp() : Timestamp.fromDate(timestamp),
      'isSeen': isSeen,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAddress != null) 'locationAddress': locationAddress,
    };
  }

  /// Khởi tạo MessageModel từ DocumentSnapshot
  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel.fromMap(data, doc.id);
  }

  /// Khởi tạo MessageModel từ Map
  factory MessageModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return MessageModel(
      id: id ?? map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? map['content'] ?? '',
      type: _stringToType(map['type']),
      mediaUrl: (map['mediaUrl'] as String?)?.isNotEmpty == true ? map['mediaUrl'] : null,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as String?,
      timestamp: map['timestamp'] != null ? parseDate(map['timestamp']) : DateTime.now(),
      isSeen: map['isSeen'] ?? false,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationAddress: map['locationAddress'] as String?,
    );
  }
}
