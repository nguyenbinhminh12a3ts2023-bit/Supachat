import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';

/// Dịch vụ Cuộc gọi thoại THẬT kết nối 2 chiều qua Firestore Signaling
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Bắt đầu một cuộc gọi thoại thật tới đối phương
  Future<String> startCall({
    required String receiverId,
    required String receiverName,
    String? receiverAvatar,
    required String callerName,
    String? callerAvatar,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final callDoc = _firestore.collection('calls').doc();
    final callId = callDoc.id;

    await callDoc.set({
      'id': callId,
      'callerId': uid,
      'callerName': callerName,
      'callerAvatar': callerAvatar ?? '',
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar ?? '',
      'status': 'ringing', // 'ringing', 'accepted', 'declined', 'ended'
      'createdAt': FieldValue.serverTimestamp(),
    });

    return callId;
  }

  /// Lắng nghe cuộc gọi đến thời gian thực
  Stream<DocumentSnapshot?> listenToIncomingCall(String myUid) {
    if (myUid.isEmpty) return const Stream.empty();

    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }
      return null;
    });
  }

  /// Lắng nghe trạng thái của một cuộc gọi cụ thể
  Stream<DocumentSnapshot> listenToCall(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  /// Chấp nhận cuộc gọi thoại
  Future<void> acceptCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'accepted',
      'connectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Từ chối cuộc gọi
  Future<void> declineCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'declined',
    });
  }

  /// Kết thúc cuộc gọi và ghi nhận thời lượng vào phòng chat
  Future<void> endCall({
    required String callId,
    required String receiverId,
    required int durationSeconds,
  }) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'durationSeconds': durationSeconds,
      });

      final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
      final s = (durationSeconds % 60).toString().padLeft(2, '0');
      final durationStr = '$m:$s';

      if (durationSeconds > 0) {
        await ChatService().sendMessage(
          receiverId: receiverId,
          text: 'Cuộc gọi thoại kết thúc · $durationStr',
        );
      }
    } catch (_) {}
  }
}

