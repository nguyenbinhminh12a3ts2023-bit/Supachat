import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'firestore_helper.dart';

/// Dịch vụ xử lý gửi/nhận tin nhắn thời gian thực và quản lý phòng chat Firestore
class ChatService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore => _customFirestore ?? AppFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _customFirestore = firestore,
        _customAuth = auth;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Tạo ID phòng chat cố định từ 2 UID (ví dụ: uid1_uid2) để tránh trùng lặp
  static String computeRoomId(String user1, String user2) {
    if (user1.compareTo(user2) < 0) {
      return '${user1}_$user2';
    } else {
      return '${user2}_$user1';
    }
  }

  String getRoomId(String user1, String user2) => computeRoomId(user1, user2);

  /// Gửi tin nhắn mới (Văn bản hoặc Hình ảnh) vào sub-collection `messages`
  Future<void> sendMessage({
    required String receiverId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? postId,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) throw Exception('Người dùng chưa đăng nhập');

    final roomId = getRoomId(senderId, receiverId);
    final now = DateTime.now();

    final message = MessageModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: text.trim(),
      type: type,
      mediaUrl: mediaUrl,
      timestamp: now,
      isSeen: false,
      postId: postId,
    );

    // 1. Lưu tin nhắn vào sub-collection 'messages' bên trong 'chat_rooms'
    // Sử dụng FieldValue.serverTimestamp() theo đúng yêu cầu
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    await messageRef.set(message.toMap(useServerTimestamp: true));

    // 2. Cập nhật thông tin tóm tắt ở document phòng chat cha
    final roomDocRef = _firestore.collection('chat_rooms').doc(roomId);

    String summaryText;
    if (type == MessageType.image) {
      summaryText = '[Hình ảnh]';
    } else if (type == MessageType.file) {
      summaryText = '[Tệp tin] $text';
    } else if (type == MessageType.sticker) {
      summaryText = '[Nhãn dán] $text';
    } else if (type == MessageType.voice) {
      summaryText = '[Tin nhắn thoại] $text';
    } else if (type == MessageType.location) {
      summaryText = '[Vị trí] $text';
    } else if (type == MessageType.callNotice) {
      summaryText = '[Cuộc gọi] $text';
    } else if (type == MessageType.screenshotAlert) {
      summaryText = 'Đã chụp màn hình';
    } else {
      summaryText = text.trim();
    }

    await roomDocRef.set({
      'id': roomId,
      'participants': [senderId, receiverId],
      'lastMessage': summaryText,
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {
        receiverId: FieldValue.increment(1),
        senderId: 0,
      },
    }, SetOptions(merge: true));

    try {
      String senderName = _auth.currentUser?.displayName ?? 'Một người bạn';
      try {
        final senderDoc = await _firestore.collection('users').doc(senderId).get();
        if (senderDoc.exists) {
          final fetchedName = senderDoc.data()?['displayName'] as String?;
          if (fetchedName != null && fetchedName.trim().isNotEmpty) {
            senderName = fetchedName.trim();
          }
        }
      } catch (_) {}
      await _firestore.collection('users').doc(receiverId).collection('notifications').add({
        'type': 'new_message',
        'title': senderName,
        'body': summaryText,
        'senderId': senderId,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (_) {}
  }

  /// Gửi tin nhắn vị trí
  Future<void> sendLocationMessage({
    required String receiverId,
    required String locationName,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) throw Exception('Người dùng chưa đăng nhập');

    final roomId = getRoomId(senderId, receiverId);
    final now = DateTime.now();

    final message = MessageModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: locationName,
      locationAddress: address,
      latitude: latitude,
      longitude: longitude,
      type: MessageType.location,
      timestamp: now,
      isSeen: false,
    );

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    await messageRef.set(message.toMap(useServerTimestamp: true));

    final roomDocRef = _firestore.collection('chat_rooms').doc(roomId);
    await roomDocRef.set({
      'id': roomId,
      'participants': [senderId, receiverId],
      'lastMessage': '[Vị trí] $locationName',
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {
        receiverId: FieldValue.increment(1),
        senderId: 0,
      },
    }, SetOptions(merge: true));
  }

  /// Gửi tin nhắn thoại (Voice message)
  Future<void> sendVoiceMessage({
    required String receiverId,
    required String audioUrl,
    required String duration,
  }) async {
    await sendMessage(
      receiverId: receiverId,
      text: duration,
      type: MessageType.voice,
      mediaUrl: audioUrl,
    );
  }

  /// Gửi tin nhắn tệp tin / tài liệu
  Future<void> sendFileMessage({
    required String receiverId,
    required String fileName,
    required String fileSize,
    required String fileUrl,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) return;

    final roomId = getRoomId(senderId, receiverId);
    final now = DateTime.now();

    final message = MessageModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: fileName,
      type: MessageType.file,
      mediaUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      timestamp: now,
      isSeen: false,
    );

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    await messageRef.set(message.toMap(useServerTimestamp: true));

    final roomDocRef = _firestore.collection('chat_rooms').doc(roomId);
    await roomDocRef.set({
      'id': roomId,
      'participants': [senderId, receiverId],
      'lastMessage': '[Tệp tin] $fileName',
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {
        receiverId: FieldValue.increment(1),
        senderId: 0,
      },
    }, SetOptions(merge: true));
  }

  /// Gửi nhãn dán sticker
  Future<void> sendStickerMessage({
    required String receiverId,
    required String stickerEmoji,
    required String stickerName,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) return;

    final roomId = getRoomId(senderId, receiverId);
    final now = DateTime.now();

    final message = MessageModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: '$stickerEmoji $stickerName',
      type: MessageType.sticker,
      timestamp: now,
      isSeen: false,
    );

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    await messageRef.set(message.toMap(useServerTimestamp: true));

    final roomDocRef = _firestore.collection('chat_rooms').doc(roomId);
    await roomDocRef.set({
      'id': roomId,
      'participants': [senderId, receiverId],
      'lastMessage': '[Nhãn dán] $stickerEmoji $stickerName',
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts': {
        receiverId: FieldValue.increment(1),
        senderId: 0,
      },
    }, SetOptions(merge: true));
  }

  /// Gửi cảnh báo đã chụp màn hình
  Future<void> sendScreenshotAlert({
    required String receiverId,
    required String userName,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) return;

    final roomId = getRoomId(senderId, receiverId);
    final now = DateTime.now();

    final message = MessageModel(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: '$userName đã chụp ảnh màn hình cuộc trò chuyện này',
      type: MessageType.screenshotAlert,
      timestamp: now,
      isSeen: false,
    );

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    await messageRef.set(message.toMap(useServerTimestamp: true));

    final roomDocRef = _firestore.collection('chat_rooms').doc(roomId);
    await roomDocRef.set({
      'id': roomId,
      'participants': [senderId, receiverId],
      'lastMessage': '[Cảnh báo chụp màn hình]',
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream lắng nghe tin nhắn trong phòng chat theo thời gian thực (Realtime Stream)
  Stream<List<MessageModel>> getMessagesStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final uid = currentUserId;
      return snapshot.docs
          .map((doc) => MessageModel.fromDocument(doc))
          .where((msg) {
            if (uid != null && msg.hiddenFor.contains(uid)) return false;
            return true;
          })
          .toList();
    });
  }

  /// Stream danh sách các phòng chat của người dùng hiện tại
  Stream<List<ChatRoomModel>> getChatRoomsStream([String? userId]) {
    final uid = userId ?? currentUserId;
    if (uid == null || uid.isEmpty) {
      return Stream.value(<ChatRoomModel>[]);
    }

    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ChatRoomModel.fromDocument(doc)).toList();
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list;
    });
  }

  /// Đánh dấu đã đọc toàn bộ tin nhắn trong phòng chat
  Future<void> markMessagesAsRead(String roomId, String otherUserId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      // 1. Reset số lượng chưa đọc của mình về 0 trong chat_rooms
      await _firestore.collection('chat_rooms').doc(roomId).set({
        'unreadCounts': {
          uid: 0,
        }
      }, SetOptions(merge: true));

      // 2. Cập nhật trạng thái isSeen: true cho các tin nhắn từ đối phương gửi tới mình
      final unreadMessages = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .where('receiverId', isEqualTo: uid)
          .where('isSeen', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isSeen': true});
      }
      await batch.commit();
    } catch (e) {
      // Bỏ qua lỗi âm thầm để không ảnh hưởng luồng chính
    }
  }

  /// Ẩn tin nhắn ở phía người dùng hiện tại
  Future<void> hideMessage(String roomId, String messageId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'hiddenFor': FieldValue.arrayUnion([uid]),
        'deletedFor': FieldValue.arrayUnion([uid]),
      });
    } catch (_) {}
  }

  /// Ghim hoặc bỏ ghim tin nhắn
  Future<void> togglePinMessage(String roomId, String messageId, bool isPinned) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isPinned': isPinned,
      });

      await _firestore.collection('chat_rooms').doc(roomId).set({
        'pinnedMessageId': isPinned ? messageId : null,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Xóa vĩnh viễn tin nhắn khỏi Firestore
  Future<void> deleteMessagePermanently(String roomId, String messageId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (_) {}
  }

  /// Xóa tin nhắn chỉ phía người dùng hiện tại (đánh dấu deletedFor / hiddenFor)
  Future<void> deleteMessageForMe(String roomId, String messageId) async {
    await hideMessage(roomId, messageId);
  }

  /// Thu hồi tin nhắn với cả hai bên (cập nhật text thành __UNSENT__)
  Future<void> unsendMessage(String roomId, String messageId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': '__UNSENT__',
        'content': '__UNSENT__',
        'mediaUrl': '',
        'type': 'text',
        'isDeleted': true,
      });
    } catch (_) {}
  }

  /// Stream danh sách tất cả người dùng khác trong hệ thống để tìm kiếm / kết bạn
  Stream<List<UserModel>> getAllUsersStream() {
    final uid = currentUserId;
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromDocument(doc))
          .where((user) => user.uid != uid)
          .toList();
    });
  }
}
