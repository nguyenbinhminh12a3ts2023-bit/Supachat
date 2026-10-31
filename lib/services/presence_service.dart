import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firestore_helper.dart';

/// Dịch vụ quản lý Trạng thái Hoạt động Thật (Realtime Presence & Online Status)
/// Tự động gửi nhịp tim (heartbeat) định kỳ 30s khi app mở
/// và cập nhật ngoại tuyến ngay lập tức khi thoát app, tắt tab hoặc ẩn nền
class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  Timer? _heartbeatTimer;
  bool _isObserverRegistered = false;

  FirebaseFirestore get _firestore => AppFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Bắt đầu theo dõi trạng thái hoạt động của người dùng hiện tại
  void start() {
    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }

    // Cập nhật online ngay lập tức
    setOnline(true);

    // Gửi nhịp tim định kỳ 3 phút để duy trì trạng thái online và tiết kiệm hạn ngạch ghi Firestore
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _pingHeartbeat();
    });
  }

  /// Dừng theo dõi (khi đăng xuất)
  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    setOnline(false);
    if (_isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
    }
  }

  /// Cập nhật trạng thái trực tuyến lên Firestore
  Future<void> setOnline(bool isOnline) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Ping nhịp tim duy trì trạng thái online
  Future<void> _pingHeartbeat() async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setOnline(true);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (_) {
        _pingHeartbeat();
      });
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.detached ||
               state == AppLifecycleState.hidden) {
      setOnline(false);
      _heartbeatTimer?.cancel();
    }
  }
}
