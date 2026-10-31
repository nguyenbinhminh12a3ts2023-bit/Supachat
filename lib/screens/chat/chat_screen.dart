import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../services/typing_service.dart';
import '../../utils/voice_recorder_helper.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/real_audio_call_screen.dart';
import '../profile/user_profile_view_screen.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator_bubble.dart';

/// Màn hình chi tiết cuộc trò chuyện thời gian thực
class ChatScreen extends StatefulWidget {
  final UserModel receiverUser;

  const ChatScreen({super.key, required this.receiverUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TypingService _typingService = TypingService();
  final StorageService _storageService = StorageService();
  late String _roomId;
  late String _currentUserId;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  String? _lastNotifiedScreenshotMsgId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _chatService.currentUserId ?? '';
    _roomId = _chatService.getRoomId(_currentUserId, widget.receiverUser.uid);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markMessagesAsRead(_roomId, widget.receiverUser.uid);
    });

    // Lắng nghe phát hiện chụp màn hình thời gian thực
    _messagesSubscription = _chatService.getMessagesStream(_roomId).listen((messages) {
      if (!mounted || messages.isEmpty) return;
      final latest = messages.first;
      if (latest.type == MessageType.screenshotAlert &&
          latest.senderId != _currentUserId &&
          latest.id != _lastNotifiedScreenshotMsgId) {
        _lastNotifiedScreenshotMsgId = latest.id;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.receiverUser.displayName} vừa chụp màn hình đoạn chat',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    VoiceRecorderHelper.stopAudio();
    AudioPlayerService.instance.stopTrack();
    _messagesSubscription?.cancel();
    _typingService.setTyping(roomId: _roomId, isTyping: false);
    super.dispose();
  }

  void _sendMessage(String text) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendTextMessage(
      receiverId: widget.receiverUser.uid,
      content: text,
    );
  }

  void _sendImage(File imageFile) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendImageMessage(
      receiverId: widget.receiverUser.uid,
      imageFile: imageFile,
    );
  }

  void _sendLocation(String locationName, String address, double lat, double lng) {
    _chatService.sendLocationMessage(
      receiverId: widget.receiverUser.uid,
      locationName: locationName,
      address: address,
      latitude: lat,
      longitude: lng,
    );
  }

  Future<void> _sendFileBytes(String fileName, String fileSize, Uint8List bytes) async {
    try {
      final fileUrl = await _storageService.uploadFileBytes(
        roomId: _roomId,
        bytes: bytes,
        fileName: fileName,
      );
      await _chatService.sendFileMessage(
        receiverId: widget.receiverUser.uid,
        fileName: fileName,
        fileSize: fileSize,
        fileUrl: fileUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi tài liệu: $e'),
            backgroundColor: AppColors.coralDanger,
          ),
        );
      }
    }
  }

  Future<void> _sendSticker(String stickerEmoji, String stickerName) async {
    await _chatService.sendStickerMessage(
      receiverId: widget.receiverUser.uid,
      stickerEmoji: stickerEmoji,
      stickerName: stickerName,
    );
  }

  Future<void> _sendVoice(String audioUrl, String duration) async {
    await _chatService.sendVoiceMessage(
      receiverId: widget.receiverUser.uid,
      audioUrl: audioUrl,
      duration: duration,
    );
  }

  void _handleScreenshotAlert() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myName = authProvider.currentUserModel?.displayName ?? 'Đối phương';

    _chatService.sendScreenshotAlert(
      receiverId: widget.receiverUser.uid,
      userName: myName,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('Đã ghi nhận thao tác chụp màn hình và gửi cảnh báo'),
            ),
          ],
        ),
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleDeleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa tin nhắn'),
        content: const Text('Xóa tin nhắn này khỏi thiết bị của bạn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _chatService.deleteMessageForMe(_roomId, message.id);
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _handleUnsendMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thu hồi tin nhắn'),
        content: const Text('Tin nhắn này sẽ bị thu hồi với cả hai bên. Bạn có chắc không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _chatService.unsendMessage(_roomId, message.id);
            },
            child: const Text('Thu hồi', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    String dateText;
    if (difference == 0) {
      dateText = 'Hôm nay';
    } else if (difference == 1) {
      dateText = 'Hôm qua';
    } else if (difference < 7 && difference > 1) {
      const weekdays = ['', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
      dateText = weekdays[date.weekday];
    } else {
      dateText = DateFormat('dd/MM/yyyy').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2235) : const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.6,
          ),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF5C6B73),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final actionBg = isDark ? AppColors.darkSecondary : AppColors.lightLavender;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<UserModel?>(
          stream: _authService.getUserStream(widget.receiverUser.uid),
          builder: (context, snapshot) {
            final user = snapshot.data ?? widget.receiverUser;
            final isOnline = user.isActuallyOnline;
            final statusText = user.onlineStatusText;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileViewScreen(user: user),
                  ),
                );
              },
              child: Row(
                children: [
                  AvatarWidget(
                    photoUrl: user.photoUrl,
                    name: user.displayName,
                    radius: 20,
                    showOnlineStatus: true,
                    isOnline: isOnline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 15, color: AppColors.primaryLight),
                            ],
                          ],
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            color: isOnline
                                ? (isDark ? AppColors.tealText : AppColors.onlineLight)
                                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          // Nút Gọi thoại THẬT 2 chiều
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: actionBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.phone_rounded,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
                size: 20,
              ),
              tooltip: 'Gọi thoại',
              onPressed: () {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final myUser = authProvider.currentUserModel;
                RealAudioCallScreen.startNewCall(
                  context: context,
                  receiverId: widget.receiverUser.uid,
                  receiverName: widget.receiverUser.displayName,
                  receiverAvatar: widget.receiverUser.photoUrl,
                  callerName: myUser?.displayName ?? 'Tôi',
                  callerAvatar: myUser?.photoUrl,
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
            children: [
              // Khu vực hiển thị tin nhắn thời gian thực
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chatService.getMessagesStream(_roomId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Lỗi tải tin nhắn: ${snapshot.error}'),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AvatarWidget(
                              photoUrl: widget.receiverUser.photoUrl,
                              name: widget.receiverUser.displayName,
                              radius: 44,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.receiverUser.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.receiverUser.email,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Hãy gửi lời chào đầu tiên',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == _currentUserId;

                        // Tính toán hiển thị Ngày phân cách (Ngày đổi)
                        // Trong ListView reverse: true, tin nhắn cũ hơn nằm ở index + 1
                        bool isDifferentDay = false;
                        if (index == messages.length - 1) {
                          isDifferentDay = true;
                        } else {
                          final olderMessage = messages[index + 1];
                          isDifferentDay = message.timestamp.year != olderMessage.timestamp.year ||
                              message.timestamp.month != olderMessage.timestamp.month ||
                              message.timestamp.day != olderMessage.timestamp.day;
                        }

                        // Hiển thị avatar đối phương ở tin nhắn dưới cùng trong chuỗi gửi liên tiếp
                        final bool isLastInGroup = index == 0 || messages[index - 1].senderId != message.senderId;

                        return Column(
                          children: [
                            if (isDifferentDay) _buildDateHeader(message.timestamp, isDark),
                            MessageBubble(
                              key: ValueKey(message.id),
                              message: message,
                              isMe: isMe,
                              senderAvatar: widget.receiverUser.photoUrl,
                              senderName: widget.receiverUser.displayName,
                              showAvatar: isLastInGroup,
                              onDelete: () => _handleDeleteMessage(message),
                              onUnsend: isMe ? () => _handleUnsendMessage(message) : null,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Typing indicator
              StreamBuilder<bool>(
                stream: _typingService.getTypingStream(
                  roomId: _roomId,
                  otherUserId: widget.receiverUser.uid,
                ),
                builder: (context, snapshot) {
                  final isTyping = snapshot.data ?? false;
                  if (!isTyping) return const SizedBox.shrink();
                  return const TypingIndicatorBubble();
                },
              ),

              // Thanh nhập tin nhắn
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  return ChatInputBar(
                    onSendMessage: _sendMessage,
                    onSendImage: _sendImage,
                    onSendImageBytes: (bytes) {
                      chatProvider.sendImageBytes(
                        receiverId: widget.receiverUser.uid,
                        bytes: bytes,
                      );
                    },
                    onSendFileBytes: _sendFileBytes,
                    onSendSticker: _sendSticker,
                    onSendLocation: _sendLocation,
                    onSendVoice: _sendVoice,
                    onScreenshotTrigger: _handleScreenshotAlert,
                    isSending: chatProvider.isSending,
                    onTypingStart: () =>
                        _typingService.setTyping(roomId: _roomId, isTyping: true),
                    onTypingStop: () =>
                        _typingService.setTyping(roomId: _roomId, isTyping: false),
                  );
                },
              ),
            ],
          ),
    );
  }
}
