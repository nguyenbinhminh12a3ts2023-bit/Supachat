import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_helper.dart';

/// Service quản lý trạng thái "đang nhập..." (Typing Indicator) trong chat
class TypingService {
  FirebaseFirestore get _firestore => AppFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Cập nhật trạng thái đang nhập lên Firestore
  Future<void> setTyping({
    required String roomId,
    required bool isTyping,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _firestore.collection('chat_rooms').doc(roomId).set({
        'typing': {uid: isTyping},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Stream theo dõi xem đối phương có đang nhập không
  Stream<bool> getTypingStream({
    required String roomId,
    required String otherUserId,
  }) {
    return _firestore.collection('chat_rooms').doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      final typingMap = data['typing'] as Map<String, dynamic>?;
      return typingMap?[otherUserId] == true;
    });
  }
}
