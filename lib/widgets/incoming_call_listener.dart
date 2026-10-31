import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/call_service.dart';
import 'avatar_widget.dart';
import 'real_audio_call_screen.dart';

/// Lắng nghe cuộc gọi đến thời gian thực và hiển thị màn hình chuông reo
class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  String? _activeShowingCallId;
  BuildContext? _dialogContext;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final myUid = authProvider.currentUserModel?.uid ?? authProvider.firebaseUser?.uid ?? '';

    if (myUid.isEmpty) {
      return widget.child;
    }

    return StreamBuilder<DocumentSnapshot?>(
      stream: CallService().listenToIncomingCall(myUid),
      builder: (context, snapshot) {
        final doc = snapshot.data;
        if (doc != null && doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final callId = data['id'] as String? ?? doc.id;
          final callerName = data['callerName'] as String? ?? 'Người gọi';
          final callerAvatar = data['callerAvatar'] as String?;
          final callerId = data['callerId'] as String? ?? '';

          if (_activeShowingCallId != callId) {
            _activeShowingCallId = callId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showIncomingDialog(context, callId, callerId, callerName, callerAvatar);
            });
          }
        } else {
          // Khi người gọi đã tắt cuộc gọi trước khi người nhận nhấc máy
          if (_activeShowingCallId != null && _dialogContext != null && _dialogContext!.mounted) {
            Navigator.of(_dialogContext!).pop();
          }
          _activeShowingCallId = null;
          _dialogContext = null;
        }

        return widget.child;
      },
    );
  }

  void _showIncomingDialog(
    BuildContext context,
    String callId,
    String callerId,
    String callerName,
    String? callerAvatar,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _dialogContext = ctx;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141724),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget(
                  photoUrl: callerAvatar,
                  name: callerName,
                  radius: 44,
                ),
                const SizedBox(height: 16),
                Text(
                  callerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đang gọi thoại cho bạn...',
                  style: TextStyle(color: AppColors.tealAccent, fontSize: 13),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Từ chối (Đỏ)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            CallService().declineCall(callId, callerId: callerId);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: AppColors.coralDanger,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Từ chối', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    // Trả lời (Xanh)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await CallService().acceptCall(callId);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RealAudioCallScreen(
                                    callId: callId,
                                    otherUserId: callerId,
                                    otherUserName: callerName,
                                    otherUserAvatar: callerAvatar,
                                    isCaller: false,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: AppColors.tealAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Trả lời', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
