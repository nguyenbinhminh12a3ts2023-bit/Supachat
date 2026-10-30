import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/chat_room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/friend_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/global_music_player_bar.dart';
import '../calls/calls_screen.dart';
import '../chat/chat_screen.dart';
import '../feed/create_post_screen.dart';
import '../feed/feed_screen.dart';
import '../friends/friends_list_screen.dart';
import '../friends/search_screen.dart';
import '../settings/settings_screen.dart';
import '../story/create_story_screen.dart';
import 'widgets/chat_tile.dart';

/// Màn hình chính SupaChat hoàn chỉnh chuẩn Mạng xã hội & Tin nhắn
/// Gồm 5 Tab điều hướng:
/// 1. Trang chủ / Bảng tin (Feed)
/// 2. Tin nhắn (Messages)
/// 3. Đăng bài (+) (Create Post)
/// 4. Bạn bè (Friends)
/// 5. Cài đặt (Settings)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0; // Mặc định mở Tab 0: Trang chủ Bảng tin
  final ChatService _chatService = ChatService();
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();

  int _selectedFilter = 0; // 0: Tất cả, 1: Chưa đọc, 2: Gần đây, 3: Nhóm

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChatSheet(BuildContext context) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_square, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Soạn tin nhắn mới',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Tìm bạn mới'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _friendService.getFriendsListStream(),
                builder: (ctx, snapshot) {
                  final friends = snapshot.data ?? [];
                  if (friends.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('Chưa có bạn bè trong danh bạ', style: TextStyle(color: textSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                              },
                              child: const Text('Kết bạn ngay'),
                            ),
                          ],
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
                        title: Text(friend.displayName, style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        subtitle: Text(
                          friend.isOnline ? 'Đang hoạt động' : '@${friend.email.split('@').first}',
                          style: TextStyle(fontSize: 12, color: friend.isOnline ? AppColors.accentGreen : textSecondary),
                        ),
                        trailing: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ChatScreen(receiverUser: friend)),
                          );
                        },
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
    final navBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final navBorder = isDark ? AppColors.darkBorder : AppColors.border;
    final activeNavColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final inactiveNavColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bg,
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          // 0: Bảng tin (Home Feed)
          FeedScreen(onNavigateToMessages: () => setState(() => _currentNavIndex = 1)),

          // 1: Tin nhắn (Figma Screen 12)
          _buildMessagesTab(currentUserId, isDark, authProvider),

          // 2: Đăng bài viết mới (+)
          CreatePostScreen(onPostSuccess: () => setState(() => _currentNavIndex = 0)),

          // 3: Bạn bè (Figma Screen 16)
          const FriendsListScreen(),

          // 4: Cài đặt (Figma Screen 18)
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh phát nhạc toàn cục khi người dùng nghe nhạc trong Feed/Story
          const GlobalMusicPlayerBar(),

          Container(
            decoration: BoxDecoration(
              color: navBg,
              border: Border(
                top: BorderSide(color: navBorder, width: 0.8),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Bảng tin',
                      activeColor: activeNavColor,
                      inactiveColor: inactiveNavColor,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Tin nhắn',
                      activeColor: activeNavColor,
                      inactiveColor: inactiveNavColor,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.add_circle_outline_rounded,
                      activeIcon: Icons.add_circle_rounded,
                      label: 'Đăng bài',
                      activeColor: activeNavColor,
                      inactiveColor: inactiveNavColor,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.people_outline_rounded,
                      activeIcon: Icons.people_alt_rounded,
                      label: 'Bạn bè',
                      activeColor: activeNavColor,
                      inactiveColor: inactiveNavColor,
                    ),
                    _buildNavItem(
                      index: 4,
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: 'Cài đặt',
                      activeColor: activeNavColor,
                      inactiveColor: inactiveNavColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentNavIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 0: Tin nhắn chuẩn Figma Screen 12
  Widget _buildMessagesTab(String currentUserId, bool isDark, AuthProvider authProvider) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final inputBg = isDark ? AppColors.darkInputBg : AppColors.inputBg;
    final actionBg = isDark ? AppColors.darkSecondary : AppColors.lightLavender;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tiêu đề trang & Action soạn tin mới
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tin nhắn',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kết nối tức thì.',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Nút Cuộc gọi
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: actionBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.phone_rounded,
                          size: 20,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                        tooltip: 'Cuộc gọi thoại',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CallsScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút Soạn tin nhắn mới
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: actionBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.edit_square,
                          size: 20,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                        tooltip: 'Soạn tin nhắn',
                        onPressed: () => _showNewChatSheet(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Thanh tìm kiếm
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
                  hintText: 'Tìm kiếm cuộc trò chuyện hoặc bạn bè...',
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

          // 3. Bạn bè trực tuyến (Stories / Active users row)
          SizedBox(
            height: 94,
            child: StreamBuilder<List<UserModel>>(
              stream: _friendService.getFriendsListStream(),
              builder: (context, snapshot) {
                final friends = snapshot.data ?? [];
                final onlineFriends = friends.where((f) => f.isOnline).toList();

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  children: [
                    // Nút "Thêm trạng thái"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: actionBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 26,
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tin của bạn',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Danh sách bạn bè trực tuyến
                    ...onlineFriends.map((friend) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(receiverUser: friend),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Column(
                            children: [
                              AvatarWidget(
                                photoUrl: friend.photoUrl,
                                name: friend.displayName,
                                radius: 27,
                                showOnlineStatus: true,
                                isOnline: true,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  friend.displayName.split(' ').last,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),

          // 4. Bộ lọc cuộc trò chuyện (Filter Chips)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 0, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Chưa đọc', 1, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Gần đây', 2, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Nhóm', 3, isDark),
              ],
            ),
          ),

          // 5. Danh sách cuộc trò chuyện
          Expanded(
            child: StreamBuilder<List<ChatRoomModel>>(
              stream: _chatService.getChatRoomsStream(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                final rooms = snapshot.data ?? [];

                final filteredRooms = rooms.where((room) {
                  // Lọc theo text search
                  if (_searchController.text.isNotEmpty) {
                    final search = _searchController.text.toLowerCase();
                    if (!room.lastMessage.toLowerCase().contains(search)) {
                      return false;
                    }
                  }
                  // Lọc theo filter chips
                  if (_selectedFilter == 1) {
                    final unread = room.unreadCounts[currentUserId] ?? 0;
                    if (unread <= 0) return false;
                  }
                  return true;
                }).toList();

                if (filteredRooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 64,
                            color: isDark
                                ? AppColors.primaryLight.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có tin nhắn nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bắt đầu kết nối và trò chuyện với bạn bè ngay.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.person_search_rounded, size: 18),
                            label: const Text('Tìm bạn bè để trò chuyện'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SearchScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: filteredRooms.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 0.8,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    indent: 82,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    return ChatTile(
                      key: ValueKey(room.id),
                      chatRoom: room,
                      currentUserId: currentUserId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, bool isDark) {
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
