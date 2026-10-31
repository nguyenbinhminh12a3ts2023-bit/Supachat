import '../../providers/locale_provider.dart';
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
import '../chat/chat_screen.dart';
import '../feed/create_post_screen.dart';
import '../feed/feed_screen.dart';
import '../friends/friends_list_screen.dart';
import '../friends/search_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/chat_tile.dart';

/// Màn hình chính SupaChat hoàn chỉnh chuẩn Figma
/// Tích hợp Floating Navigation Bar & Global Music Player
/// 5 Tab điều hướng:
/// 0: Bảng tin (Feed & Stories)
/// 1: Tin nhắn (Chats list)
/// 2: Tạo bài viết (+) (Create post)
/// 3: Bạn bè (Friends & Discovery)
/// 4: Cài đặt (Settings)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0; // Mặc định mở Tab 0: Bảng tin
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
                          style: TextStyle(fontSize: 12, color: friend.isOnline ? AppColors.tealAccent : textSecondary),
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
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final activeColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bg,
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          // 0: Bảng tin (Feed & Stories)
          FeedScreen(onNavigateToMessages: () => setState(() => _currentNavIndex = 1)),

          // 1: Tin nhắn (Chats list)
          _buildMessagesTab(currentUserId, isDark, authProvider),

          // 2: Tạo bài viết mới (+)
          CreatePostScreen(onPostSuccess: () => setState(() => _currentNavIndex = 0)),

          // 3: Bạn bè (Friends & Discovery)
          const FriendsListScreen(),

          // 4: Cài đặt (Settings)
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _currentNavIndex == 2 ? null : SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating Global Music Player
            const GlobalMusicPlayerBar(),

            // Floating Navigation Bar chuẩn Figma
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: isDark ? 0.95 : 0.98),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tab 0: Bảng tin
                  _buildFloatingNavItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: localeProvider.t('Bảng tin', 'Feed'),
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),

                  // Tab 1: Tin nhắn (with red dot)
                  _buildFloatingNavItem(
                    index: 1,
                    icon: Icons.forum_outlined,
                    activeIcon: Icons.forum_rounded,
                    label: localeProvider.t('Tin nhắn', 'Messages'),
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    hasUnreadBadge: true,
                  ),

                  // Tab 2: Tạo bài viết (+ Center Floating Gradient Button)
                  GestureDetector(
                    onTap: () => setState(() => _currentNavIndex = 2),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),

                  // Tab 3: Bạn bè
                  _buildFloatingNavItem(
                    index: 3,
                    icon: Icons.people_outline_rounded,
                    activeIcon: Icons.people_rounded,
                    label: localeProvider.t('Bạn bè', 'Friends'),
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),

                  // Tab 4: Cài đặt
                  _buildFloatingNavItem(
                    index: 4,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: localeProvider.t('Cài đặt', 'Settings'),
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
    bool hasUnreadBadge = false,
  }) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentNavIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (hasUnreadBadge)
                  Positioned(
                    top: -1,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.coralDanger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 1: Tin nhắn chuẩn Figma Chats list · Light / Dark
  Widget _buildMessagesTab(String currentUserId, bool isDark, AuthProvider authProvider) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final inputBg = isDark ? AppColors.darkInputBg : AppColors.inputBg;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: "Tin nhắn" + Nút Soạn tin mới (Square-pen)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tin nhắn',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: textPrimary,
                  ),
                ),
                InkWell(
                  onTap: () => _showNewChatSheet(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondary : AppColors.lightLavender,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.edit_square, color: AppColors.primary, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // 2. Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cuộc trò chuyện',
                  hintStyle: TextStyle(fontSize: 14, color: textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // 3. Filter Chips: "Tất cả", "Chưa đọc", "Gần đây", "Nhóm" (Figma element)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(Provider.of<LocaleProvider>(context).t('Tất cả', 'All'), 0, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(Provider.of<LocaleProvider>(context).t('Chưa đọc', 'Unread'), 1, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(Provider.of<LocaleProvider>(context).t('Gần đây', 'Recent'), 2, isDark),
                const SizedBox(width: 8),
                _buildFilterChip(Provider.of<LocaleProvider>(context).t('Nhóm', 'Groups'), 3, isDark),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 4. Danh sách cuộc trò chuyện
          Expanded(
            child: StreamBuilder<List<ChatRoomModel>>(
              stream: _chatService.getChatRoomsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                var rooms = snapshot.data ?? [];

                // Lọc theo từ khóa tìm kiếm
                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  rooms = rooms.where((r) {
                    final otherId = r.getOtherUserId(currentUserId).toLowerCase();
                    final lastMsg = r.lastMessage.toLowerCase();
                    return otherId.contains(query) || lastMsg.contains(query);
                  }).toList();
                }

                // Lọc theo chip
                if (_selectedFilter == 1) {
                  rooms = rooms.where((r) => r.getUnreadCount(currentUserId) > 0).toList();
                }

                if (rooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 52, color: textSecondary.withValues(alpha: 0.3)),
                          const SizedBox(height: 14),
                          Text(
                            'Chưa có cuộc trò chuyện nào',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kết nối với bạn bè để bắt đầu những cuộc trò chuyện hay!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () => _showNewChatSheet(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Bắt đầu nhắn tin',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return ChatTile(
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
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary : AppColors.primary)
              : (isDark ? AppColors.darkSurface : AppColors.inputBg),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
