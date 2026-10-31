import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/avatar_widget.dart';
import '../../chat/chat_screen.dart';

/// Ô hiển thị một phòng chat trong danh sách gần đây chuẩn Figma
class ChatTile extends StatelessWidget {
  static final AuthService _authService = AuthService();
  final ChatRoomModel chatRoom;
  final String currentUserId;
  final VoidCallback? onTap;

  const ChatTile({
    super.key,
    required this.chatRoom,
    required this.currentUserId,
    this.onTap,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(date);
    } else if (today.difference(messageDate).inDays == 1) {
      return 'Hôm qua';
    } else if (today.difference(messageDate).inDays < 7) {
      return DateFormat('E', 'vi').format(date);
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final otherUserId = chatRoom.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    final unreadCount = chatRoom.unreadCounts[currentUserId] ?? 0;
    final isMeSender = chatRoom.lastMessageSenderId == currentUserId;

    return StreamBuilder<UserModel?>(
      stream: _authService.getUserStream(otherUserId),
      builder: (context, snapshot) {
        final otherUser = snapshot.data;
        final displayName = otherUser?.displayName ?? 'Đang tải...';
        final photoUrl = otherUser?.photoUrl;
        final isOnline = otherUser?.isOnline ?? false;

        return InkWell(
          onTap: onTap ?? () {
            if (otherUser != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(receiverUser: otherUser),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar kèm chấm online
                AvatarWidget(
                  photoUrl: photoUrl,
                  name: displayName,
                  radius: 26,
                  showOnlineStatus: true,
                  isOnline: isOnline,
                ),

                const SizedBox(width: 14),

                // Tên & Tin nhắn cuối
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(chatRoom.lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                  : textSecondary,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isMeSender
                                  ? 'Bạn: ${chatRoom.lastMessage}'
                                  : chatRoom.lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: unreadCount > 0
                                    ? textPrimary
                                    : textSecondary,
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Huy hiệu số tin nhắn chưa đọc
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
