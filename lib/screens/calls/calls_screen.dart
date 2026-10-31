import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/firestore_helper.dart';
import '../../services/friend_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/real_audio_call_screen.dart';

/// Màn hình Lịch sử & Cuộc gọi thoại thời gian thực (Real 2-Way Audio Call)
class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  int _selectedFilter = 0; // 0: Tất cả, 1: Gọi nhỡ
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCallTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Hôm nay, ${DateFormat('HH:mm').format(dt)}';
    } else if (diff.inDays == 1) {
      return 'Hôm qua, ${DateFormat('HH:mm').format(dt)}';
    } else {
      return DateFormat('dd/MM, HH:mm').format(dt);
    }
  }

  void _showNewCallSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Chọn bạn bè để gọi thoại',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _friendService.getFriendsListStream(),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final friends = snapshot.data ?? [];
                  if (friends.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Chưa có bạn bè trong danh bạ để thực hiện cuộc gọi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                    itemBuilder: (ctx, index) {
                      final friend = friends[index];
                      return ListTile(
                        leading: AvatarWidget(
                          photoUrl: friend.photoUrl,
                          name: friend.displayName,
                          radius: 22,
                          showOnlineStatus: true,
                          isOnline: friend.isOnline,
                        ),
                        title: Text(
                          friend.displayName,
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        subtitle: Text(
                          friend.isOnline ? 'Đang trực tuyến' : '@${friend.email.split('@').first}',
                          style: TextStyle(
                            fontSize: 12,
                            color: friend.isOnline ? AppColors.accentGreen : textSecondary,
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: const Text('Gọi ngay'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            RealAudioCallScreen.startNewCall(
                              context: context,
                              callee: friend,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final inputBg = isDark ? AppColors.darkInputBg : AppColors.inputBg;
    final actionBg = isDark ? AppColors.darkSecondary : AppColors.lightLavender;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Tiêu đề trang & Nút gọi mới
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cuộc gọi',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cuộc gọi thoại thời gian thực.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: actionBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.add_call,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      onPressed: () => _showNewCallSheet(context),
                    ),
                  ),
                ],
              ),
            ),

            // Thanh tìm kiếm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm cuộc gọi...',
                    hintStyle: TextStyle(fontSize: 14, color: textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Bộ lọc: Tất cả / Gọi nhỡ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', 0, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Gọi nhỡ', 1, isDark),
                ],
              ),
            ),

            // Danh sách cuộc gọi từ Firestore (Real calls collection)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: AppFirestore.instance
                    .collection('calls')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Lọc những cuộc gọi liên quan đến người dùng hiện tại
                  final myCalls = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final callerId = data['callerId'] as String? ?? '';
                    final calleeId = data['calleeId'] as String? ?? '';
                    return callerId == currentUserId || calleeId == currentUserId;
                  }).toList();

                  final filteredCalls = myCalls.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] as String? ?? '';
                    final callerId = data['callerId'] as String? ?? '';
                    final isMissed = status == 'declined' || (status == 'ended' && callerId != currentUserId);

                    if (_selectedFilter == 1 && !isMissed) return false;

                    final callerName = data['callerName'] as String? ?? '';
                    final calleeName = data['calleeName'] as String? ?? '';
                    final searchKeyword = _searchController.text.toLowerCase().trim();

                    if (searchKeyword.isNotEmpty &&
                        !callerName.toLowerCase().contains(searchKeyword) &&
                        !calleeName.toLowerCase().contains(searchKeyword)) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filteredCalls.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_disabled_rounded,
                              size: 56,
                              color: isDark ? AppColors.primaryLight.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 1 ? 'Không có cuộc gọi nhỡ' : 'Chưa có lịch sử cuộc gọi',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nhấn vào nút bên dưới để bắt đầu cuộc gọi thoại thật với bạn bè.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: textSecondary),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              icon: const Icon(Icons.phone_rounded),
                              label: const Text('Bắt đầu cuộc gọi'),
                              onPressed: () => _showNewCallSheet(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: filteredCalls.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = filteredCalls[index].data() as Map<String, dynamic>;
                      final callerId = data['callerId'] as String? ?? '';
                      final isOutgoing = callerId == currentUserId;
                      final otherId = isOutgoing ? (data['calleeId'] as String? ?? '') : callerId;
                      final otherName = isOutgoing
                          ? (data['calleeName'] as String? ?? 'Người dùng')
                          : (data['callerName'] as String? ?? 'Người dùng');
                      final otherAvatar = isOutgoing
                          ? (data['calleeAvatar'] as String?)
                          : (data['callerAvatar'] as String?);
                      final status = data['status'] as String? ?? 'ended';
                      final isMissed = status == 'declined';

                      DateTime time = DateTime.now();
                      if (data['createdAt'] is Timestamp) {
                        time = (data['createdAt'] as Timestamp).toDate();
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 0.8),
                        ),
                        child: Row(
                          children: [
                            AvatarWidget(
                              photoUrl: otherAvatar,
                              name: otherName,
                              radius: 24,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    otherName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isMissed ? AppColors.coralDanger : textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        isMissed
                                            ? Icons.call_missed_rounded
                                            : isOutgoing
                                                ? Icons.call_made_rounded
                                                : Icons.call_received_rounded,
                                        size: 14,
                                        color: isMissed
                                            ? AppColors.coralDanger
                                            : isOutgoing
                                                ? AppColors.primaryLight
                                                : AppColors.accentGreen,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatCallTime(time),
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                              onPressed: () {
                                final targetUser = UserModel(
                                  uid: otherId,
                                  email: '',
                                  displayName: otherName,
                                  photoUrl: otherAvatar,
                                  createdAt: DateTime.now(),
                                );
                                RealAudioCallScreen.startNewCall(
                                  context: context,
                                  callee: targetUser,
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Footer bảo mật
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Cuộc gọi thoại bảo mật & mã hóa đầu cuối.',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, bool isDark) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isDark
                  ? AppColors.darkSurface
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.border,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
