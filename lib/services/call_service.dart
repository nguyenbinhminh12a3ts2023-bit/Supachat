import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'chat_service.dart';
import 'firestore_helper.dart';

/// Dịch vụ Cuộc gọi thoại THẬT kết nối 2 chiều qua Firestore Signaling
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  FirebaseFirestore get _firestore => AppFirestore.instance;
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
      'calleeId': receiverId,
      'receiverName': receiverName,
      'calleeName': receiverName,
      'receiverAvatar': receiverAvatar ?? '',
      'calleeAvatar': receiverAvatar ?? '',
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
  Future<void> declineCall(String callId, {String? callerId}) async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      final targetCallerId = callerId ?? (doc.data()?['callerId'] as String?);

      await _firestore.collection('calls').doc(callId).update({
        'status': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
      });

      if (targetCallerId != null && targetCallerId.isNotEmpty) {
        await ChatService().sendMessage(
          receiverId: targetCallerId,
          text: 'Cuộc gọi nhỡ',
          type: MessageType.callNotice,
        );
      }
    } catch (_) {}
  }

  /// Kết thúc cuộc gọi và ghi nhận thông báo vào phòng chat
  Future<void> endCall({
    required String callId,
    required String receiverId,
    required int durationSeconds,
  }) async {
    // 1. Cập nhật trạng thái cuộc gọi trên collection calls
    if (callId.isNotEmpty) {
      try {
        await _firestore.collection('calls').doc(callId).update({
          'status': 'ended',
          'durationSeconds': durationSeconds,
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    // 2. Ghi nhận thông báo vào phòng chat độc lập
    try {
      final senderId = currentUserId;
      if (senderId == null) return;

      if (durationSeconds > 0) {
        final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
        final s = (durationSeconds % 60).toString().padLeft(2, '0');
        final durationStr = '$m:$s';

        await ChatService().sendMessage(
          receiverId: receiverId,
          text: 'Cuộc gọi thoại · $durationStr',
          type: MessageType.callNotice,
        );
      } else {
        // Cuộc gọi nhỡ (người nhận không nhấc máy hoặc người gọi tắt trước khi kết nối)
        await ChatService().sendMessage(
          receiverId: receiverId,
          text: 'Cuộc gọi nhỡ',
          type: MessageType.callNotice,
        );
      }
    } catch (e) {
      debugPrint('Lỗi ghi nhận cuộc gọi: $e');
    }
  }
}
