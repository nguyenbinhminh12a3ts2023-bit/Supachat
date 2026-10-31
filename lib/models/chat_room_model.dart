import 'package:cloud_firestore/cloud_firestore.dart';

/// Model thông tin phòng chat giữa 2 người dùng
class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageTime,
    this.unreadCounts = const {},
  });

  /// Lấy ID của đối phương trong phòng chat
  String getOtherUserId(String myId) {
    return participants.firstWhere((id) => id != myId, orElse: () => '');
  }

  /// Lấy số tin nhắn chưa đọc của người dùng hiện tại
  int getUnreadCount(String myId) {
    return unreadCounts[myId] ?? 0;
  }

  /// Chuyển đổi sang Map để lưu trên Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCounts': unreadCounts,
    };
  }

  /// Khởi tạo ChatRoomModel từ DocumentSnapshot
  factory ChatRoomModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatRoomModel.fromMap(data, doc.id);
  }

  /// Khởi tạo ChatRoomModel từ Map
  factory ChatRoomModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    Map<String, int> parseUnread(dynamic value) {
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    return ChatRoomModel(
      id: id ?? map['id'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null ? parseDate(map['lastMessageTime']) : DateTime.now(),
      unreadCounts: parseUnread(map['unreadCounts']),
    );
  }
}
