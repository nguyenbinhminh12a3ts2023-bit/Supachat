import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import 'avatar_widget.dart';

/// Màn hình/Hộp thoại Cuộc gọi đang hoạt động (Active Call Simulation)
/// Có bấm tắt/bật mic, bật loa ngoài, bật/tắt camera và đếm giờ thời gian thực
class ActiveCallDialog extends StatefulWidget {
  final String userName;
  final String? photoUrl;
  final String? receiverId;
  final String? roomId;
  final bool isVideo;

  const ActiveCallDialog({
    super.key,
    required this.userName,
    this.photoUrl,
    this.receiverId,
    this.roomId,
    this.isVideo = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String userName,
    String? photoUrl,
    String? receiverId,
    String? roomId,
    bool isVideo = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActiveCallDialog(
        userName: userName,
        photoUrl: photoUrl,
        receiverId: receiverId,
        roomId: roomId,
        isVideo: isVideo,
      ),
    );
  }

  @override
  State<ActiveCallDialog> createState() => _ActiveCallDialogState();
}

class _ActiveCallDialogState extends State<ActiveCallDialog> {
  Timer? _timer;
  int _seconds = 0;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  late bool _isCameraOn;

  @override
  void initState() {
    super.initState();
    _isCameraOn = widget.isVideo;

    // Giả lập kết nối sau 1.8 giây
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endCall() {
    _timer?.cancel();
    final durationStr = _formatDuration(_seconds);

    // Lưu thông báo cuộc gọi vào Firestore nếu có receiverId
    if (widget.receiverId != null && _seconds > 0) {
      try {
        final callTypeStr = widget.isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
        ChatService().sendMessage(
          receiverId: widget.receiverId!,
          text: '$callTypeStr kết thúc · $durationStr',
          type: MessageType.text,
        );
      } catch (_) {}
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _seconds > 0
              ? 'Cuộc gọi kết thúc · Thời lượng: $durationStr'
              : 'Đã hủy cuộc gọi',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        decoration: BoxDecoration(
          color: const Color(0xFF141724),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                          size: 14,
                          color: AppColors.tealAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isVideo ? 'Video HD' : 'Thoại E2EE',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                    onPressed: _endCall,
                  ),
                ],
              ),
            ),

            // Profile & Call Info
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isConnected)
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    AvatarWidget(
                      photoUrl: widget.photoUrl,
                      name: widget.userName,
                      radius: 50,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isConnected ? _formatDuration(_seconds) : 'Đang đổ chuông...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: _isConnected ? FontWeight.w600 : FontWeight.normal,
                    color: _isConnected ? AppColors.tealAccent : Colors.white60,
                  ),
                ),
              ],
            ),

            // Call Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _isMuted ? 'Bật mic' : 'Tắt mic',
                        isActive: _isMuted,
                        onTap: () => setState(() => _isMuted = !_isMuted),
                      ),
                      _buildControlButton(
                        icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: 'Loa ngoài',
                        isActive: _isSpeaker,
                        onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                      ),
                      if (widget.isVideo)
                        _buildControlButton(
                          icon: _isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          label: 'Camera',
                          isActive: !_isCameraOn,
                          onTap: () => setState(() => _isCameraOn = !_isCameraOn),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Nút kết thúc cuộc gọi
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.coralDanger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.coralDanger,
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
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

  Widget _buildControlButton({
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFF141724) : Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}

