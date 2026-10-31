import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái của lời mời kết bạn
class FriendRequestStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
}

/// Model lưu thông tin lời mời kết bạn trong collection `friend_requests`
class FriendRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderEmail;
  final String senderName;
  final String? senderPhotoUrl;
  final String status;
  final DateTime timestamp;

  FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderEmail,
    required this.senderName,
    this.senderPhotoUrl,
    this.status = FriendRequestStatus.pending,
    required this.timestamp,
  });

  /// Chuyển đổi sang Map để lưu trên Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl ?? '',
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  /// Khởi tạo từ DocumentSnapshot
  factory FriendRequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FriendRequestModel.fromMap(data, doc.id);
  }

  /// Khởi tạo từ Map
  factory FriendRequestModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return FriendRequestModel(
      id: id ?? map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      senderName: map['senderName'] ?? 'Người dùng',
      senderPhotoUrl: (map['senderPhotoUrl'] as String?)?.isNotEmpty == true
          ? map['senderPhotoUrl']
          : null,
      status: map['status'] ?? FriendRequestStatus.pending,
      timestamp: map['timestamp'] != null ? parseDate(map['timestamp']) : DateTime.now(),
    );
  }
}
