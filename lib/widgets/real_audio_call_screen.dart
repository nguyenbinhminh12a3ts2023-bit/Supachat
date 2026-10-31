import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/call_service.dart';
import '../utils/call_ringtone_helper.dart';
import '../utils/real_call_audio_helper.dart';
import 'avatar_widget.dart';

/// Màn hình Cuộc gọi thoại THẬT 2 chiều (Real Audio Call Screen)
class RealAudioCallScreen extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? callerName;
  final String? callerAvatar;
  final bool isCaller;

  const RealAudioCallScreen({
    super.key,
    required this.callId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.callerName,
    this.callerAvatar,
    required this.isCaller,
  });

  static void startNewCall({
    required BuildContext context,
    String receiverId = '',
    String receiverName = '',
    String? receiverAvatar,
    String? callerName,
    String? callerAvatar,
    UserModel? callee,
  }) {
    final targetReceiverId = callee?.uid ?? receiverId;
    final targetReceiverName = callee?.displayName ?? receiverName;
    final targetReceiverAvatar = callee?.photoUrl ?? receiverAvatar;

    final user = FirebaseAuth.instance.currentUser;
    final resolvedCallerName = callerName ?? user?.displayName ?? 'Tôi';
    final resolvedCallerAvatar = callerAvatar ?? user?.photoURL;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealAudioCallScreen(
          callId: '',
          otherUserId: targetReceiverId,
          otherUserName: targetReceiverName,
          otherUserAvatar: targetReceiverAvatar,
          callerName: resolvedCallerName,
          callerAvatar: resolvedCallerAvatar,
          isCaller: true,
        ),
      ),
    );
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
  String _activeCallId = '';

  @override
  void initState() {
    super.initState();
    _activeCallId = widget.callId;
    if (widget.isCaller) {
      CallRingtoneHelper.startRingbackTone();
      if (_activeCallId.isEmpty) {
        _initCallerCall();
      } else {
        _startSignaling();
      }
    } else {
      _startSignaling();
    }
  }

  Future<void> _initCallerCall() async {
    try {
      final id = await _callService.startCall(
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        receiverAvatar: widget.otherUserAvatar,
        callerName: widget.callerName ?? 'Tôi',
        callerAvatar: widget.callerAvatar,
      );
      if (!mounted) return;
      setState(() {
        _activeCallId = id;
      });
      _startSignaling();
    } catch (e) {
      if (!mounted) return;
      CallRingtoneHelper.stopAll();
      setState(() {
        _statusText = 'Không thể kết nối: $e';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _startSignaling() {
    if (_activeCallId.isEmpty) return;
    _listenCallStatus();
    RealCallAudioHelper.startCallSession(
      callId: _activeCallId,
      isCaller: widget.isCaller,
      onConnectedChange: (connected) {
        if (mounted && connected && !_isConnected) {
          CallRingtoneHelper.stopAll();
          setState(() {
            _isConnected = true;
            _statusText = 'Đang đàm thoại';
          });
          _startTimer();
        }
      },
    );
  }

  void _listenCallStatus() {
    if (_activeCallId.isEmpty) return;
    _callSub?.cancel();
    _callSub = _callService.listenToCall(_activeCallId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final status = data['status'] as String? ?? '';

      if (status == 'accepted' && !_isConnected) {
        CallRingtoneHelper.stopAll();
        setState(() {
          _isConnected = true;
          _statusText = 'Đang đàm thoại';
        });
        _startTimer();
      } else if (status == 'declined') {
        CallRingtoneHelper.stopAll();
        setState(() {
          _statusText = 'Cuộc gọi bị từ chối';
        });
        RealCallAudioHelper.endCallSession();
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (status == 'ended') {
        CallRingtoneHelper.stopAll();
        RealCallAudioHelper.endCallSession();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
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
    CallRingtoneHelper.stopAll();
    RealCallAudioHelper.endCallSession();
    if (_activeCallId.isNotEmpty) {
      await _callService.endCall(
        callId: _activeCallId,
        receiverId: widget.otherUserId,
        durationSeconds: _seconds,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callSub?.cancel();
    CallRingtoneHelper.stopAll();
    RealCallAudioHelper.endCallSession();
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

            // Recipient Profile with Concentric Rings
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ring 3
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Middle Ring 2
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Inner Ring 1 & Halo
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
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
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isConnected)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.tealAccent,
                        ),
                      ),
                    Text(
                      _isConnected ? _formatDuration(_seconds) : _statusText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _isConnected ? FontWeight.w600 : FontWeight.normal,
                        color: _isConnected ? AppColors.tealAccent : Colors.white60,
                      ),
                    ),
                  ],
                ),

              ],
            ),

            // Frosted Call Control Dock chuẩn Figma
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1E2C).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Tắt mic
                    _buildControl(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: 'Tắt tiếng',
                      isActive: _isMuted,
                      onTap: () {
                        final next = !_isMuted;
                        setState(() => _isMuted = next);
                        RealCallAudioHelper.setMute(next);
                      },
                    ),
                    // 2. Loa ngoài
                    _buildControl(
                      icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      label: 'Loa ngoài',
                      isActive: _isSpeaker,
                      onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                    ),
                    // 3. Tin nhắn
                    _buildControl(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Tin nhắn',
                      isActive: false,
                      onTap: () {
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                    // 4. Kết thúc cuộc gọi
                    _buildEndCallControl(),
                  ],
                ),
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

  Widget _buildEndCallControl() {
    return Column(
      children: [
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.coralDanger,
              boxShadow: [
                BoxShadow(
                  color: AppColors.coralDanger.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kết thúc',
          style: TextStyle(fontSize: 12, color: AppColors.coralDanger, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
