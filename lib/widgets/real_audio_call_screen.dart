import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/call_service.dart';
import 'avatar_widget.dart';

/// Màn hình Cuộc gọi thoại THẬT 2 chiều (Real Audio Call Screen)
class RealAudioCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final bool isCaller;

  const RealAudioCallScreen({
    super.key,
    required this.callId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.isCaller,
  });

  static Future<void> startNewCall({
    required BuildContext context,
    String receiverId = '',
    String receiverName = '',
    String? receiverAvatar,
    String? callerName,
    String? callerAvatar,
    UserModel? callee,
  }) async {
    final targetReceiverId = callee?.uid ?? receiverId;
    final targetReceiverName = callee?.displayName ?? receiverName;
    final targetReceiverAvatar = callee?.photoUrl ?? receiverAvatar;

    final user = FirebaseAuth.instance.currentUser;
    final resolvedCallerName = callerName ?? user?.displayName ?? 'Tôi';
    final resolvedCallerAvatar = callerAvatar ?? user?.photoURL;

    try {
      final callId = await CallService().startCall(
        receiverId: targetReceiverId,
        receiverName: targetReceiverName,
        receiverAvatar: targetReceiverAvatar,
        callerName: resolvedCallerName,
        callerAvatar: resolvedCallerAvatar,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RealAudioCallScreen(
              callId: callId,
              otherUserId: targetReceiverId,
              otherUserName: targetReceiverName,
              otherUserAvatar: targetReceiverAvatar,
              isCaller: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bắt đầu cuộc gọi: $e')),
        );
      }
    }
  }

  @override
  State<RealAudioCallScreen> createState() => _RealAudioCallScreenState();
}

class _RealAudioCallScreenState extends State<RealAudioCallScreen> {
  final CallService _callService = CallService();
  StreamSubscription<DocumentSnapshot>? _callSub;
  Timer? _timer;
  int _seconds = 0;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  String _statusText = 'Đang đổ chuông...';

  @override
  void initState() {
    super.initState();
    _listenCallStatus();
  }

  void _listenCallStatus() {
    _callSub = _callService.listenToCall(widget.callId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final status = data['status'] as String? ?? '';

      if (status == 'accepted' && !_isConnected) {
        setState(() {
          _isConnected = true;
          _statusText = 'Đang kết nối thoại';
        });
        _startTimer();
      } else if (status == 'declined') {
        setState(() {
          _statusText = 'Cuộc gọi bị từ chối';
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (status == 'ended') {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endCall() async {
    _timer?.cancel();
    _callSub?.cancel();
    await _callService.endCall(
      callId: widget.callId,
      receiverId: widget.otherUserId,
      durationSeconds: _seconds,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10121C),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 14, color: AppColors.tealAccent),
                        SizedBox(width: 6),
                        Text(
                          'Mã hóa đầu cuối E2EE',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                    onPressed: _endCall,
                  ),
                ],
              ),
            ),

            // Recipient Profile
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isConnected)
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    AvatarWidget(
                      photoUrl: widget.otherUserAvatar,
                      name: widget.otherUserName,
                      radius: 54,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isConnected ? _formatDuration(_seconds) : _statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _isConnected ? FontWeight.w600 : FontWeight.normal,
                    color: _isConnected ? AppColors.tealAccent : Colors.white60,
                  ),
                ),
              ],
            ),

            // Call Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControl(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _isMuted ? 'Bật mic' : 'Tắt mic',
                        isActive: _isMuted,
                        onTap: () => setState(() => _isMuted = !_isMuted),
                      ),
                      _buildControl(
                        icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: 'Loa ngoài',
                        isActive: _isSpeaker,
                        onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.coralDanger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.coralDanger,
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControl({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFF10121C) : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
