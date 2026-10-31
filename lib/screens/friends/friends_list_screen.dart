import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/friend_request_model.dart';
import '../../models/user_model.dart';
import '../../providers/locale_provider.dart';
import '../../services/friend_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/real_audio_call_screen.dart';
import '../chat/chat_screen.dart';
import 'search_screen.dart';

/// Màn hình Bạn bè chuẩn Figma (Screen 16: Bạn bè)
class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0; // 0: Tất cả, 1: Trực tuyến, 2: Lời mời

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final inputBg = isDark ? AppColors.darkInputBg : AppColors.inputBg;
    final actionBg = isDark ? AppColors.darkSecondary : AppColors.lightLavender;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Tiêu đề trang & Action Thêm bạn mới
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeProvider.t('Bạn bè', 'Friends'),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localeProvider.t('Kết nối với những người bạn quan tâm.', 'Connect with people you care about.'),
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
                        Icons.person_add_rounded,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 2. Thanh tìm kiếm bạn bè
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
                  readOnly: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(initialQuery: _searchController.text.trim()),
                      ),
                    );
                  },
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(initialQuery: query.trim()),
                      ),
                    );
                  },
                  style: TextStyle(fontSize: 14, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: localeProvider.t('Tìm người bạn muốn kết nối', 'Search friends...'),
                    hintStyle: TextStyle(fontSize: 14, color: textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // 3. Bộ lọc: Tất cả / Trực tuyến / Lời mời
            StreamBuilder<List<FriendRequestModel>>(
              stream: _friendService.getReceivedFriendRequestsStream(),
              builder: (context, reqSnapshot) {
                final pendingCount = reqSnapshot.data?.length ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Row(
                    children: [
                      _buildFilterChip(localeProvider.t('Tất cả', 'All'), 0, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip(localeProvider.t('Trực tuyến', 'Online'), 1, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        pendingCount > 0
                            ? '${localeProvider.t("Lời mời", "Requests")} ($pendingCount)'
                            : localeProvider.t('Lời mời', 'Requests'),
                        2,
                        isDark,
                        badgeCount: pendingCount,
                      ),
                    ],
                  ),
                );
              },
            ),

            // 4. Danh sách bạn bè hoặc Lời mời kết bạn
            Expanded(
              child: _selectedFilter == 2
                  ? _buildRequestsView(isDark, textPrimary, textSecondary)
                  : _buildFriendsListView(isDark, textPrimary, textSecondary, actionBg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsView(bool isDark, Color textPrimary, Color textSecondary) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: _friendService.getReceivedFriendRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Không có lời mời kết bạn nào',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Khi người dùng khác gửi lời mời kết bạn cho bạn, lời mời sẽ xuất hiện tại đây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: requests.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
          itemBuilder: (context, index) {
            final req = requests[index];
            return ListTile(
              leading: AvatarWidget(photoUrl: req.senderPhotoUrl, name: req.senderName, radius: 24),
              title: Text(req.senderName, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
              subtitle: Text('@${req.senderEmail.split('@').first}', style: TextStyle(color: textSecondary, fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () async {
                      await _friendService.acceptFriendRequest(req);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã chấp nhận kết bạn với ${req.senderName}!'),
                            backgroundColor: AppColors.accentGreen,
                          ),
                        );
                      }
                    },
                    child: const Text('Chấp nhận', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () async {
                      await _friendService.rejectFriendRequest(req);
                    },
                    child: const Text('Từ chối', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsListView(bool isDark, Color textPrimary, Color textSecondary, Color actionBg) {
    return StreamBuilder<List<UserModel>>(
      stream: _friendService.getFriendsListStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final allFriends = snapshot.data ?? [];

        final filtered = allFriends.where((friend) {
          if (_selectedFilter == 1 && !friend.isOnline) return false;
          if (_searchController.text.isNotEmpty &&
              !friend.displayName.toLowerCase().contains(_searchController.text.toLowerCase()) &&
              !friend.email.toLowerCase().contains(_searchController.text.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 64,
                    color: isDark
                        ? AppColors.primaryLight.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 1
                        ? 'Không có bạn bè trực tuyến'
                        : 'Chưa có bạn bè nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhấn nút tìm kiếm bên trên để kết nối với bạn bè mới.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                  if (_searchController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(initialQuery: _searchController.text.trim()),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Tìm "${_searchController.text}" trên SupaChat',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 0.8,
            color: isDark ? AppColors.darkBorder : AppColors.border,
            indent: 76,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final friend = filtered[index];
            return ListTile(
              key: ValueKey(friend.uid),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: AvatarWidget(
                photoUrl: friend.photoUrl,
                name: friend.displayName,
                radius: 26,
                showOnlineStatus: true,
                isOnline: friend.isOnline,
              ),
              title: Text(
                friend.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              subtitle: Text(
                friend.bio?.isNotEmpty == true
                    ? friend.bio!
                    : '@${friend.email.split('@').first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút Gọi thoại
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: actionBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.phone_rounded,
                        size: 18,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      onPressed: () {
                        RealAudioCallScreen.startNewCall(
                          context: context,
                          callee: friend,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút Nhắn tin
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(receiverUser: friend),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(receiverUser: friend),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, int index, bool isDark, {int badgeCount = 0}) {
    final isSelected = _selectedFilter == index;
    final activeBg = isDark ? AppColors.darkSecondary : AppColors.lightLavender;
    final activeText = isDark ? AppColors.primaryLight : AppColors.primary;
    final inactiveText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.2)
              : Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }
}
