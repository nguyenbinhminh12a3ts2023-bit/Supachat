import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/friend_request_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../services/post_service.dart';
import '../../widgets/avatar_widget.dart';
import '../chat/chat_screen.dart';

/// Màn hình Tìm kiếm & Khám phá chuẩn Design System Figma
/// - Tìm kiếm người dùng thật theo Tên / Email / Handle (Debounced tự động tìm khi gõ)
/// - Hiển thị trạng thái Kết bạn, Đã gửi lời mời, hoặc Nhắn tin
/// - Gợi ý kết bạn từ người dùng thật trên Firestore
/// - Quản lý danh sách lời mời kết bạn (Chấp nhận / Từ chối)
class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  final AuthService _authService = AuthService();
  final PostService _postService = PostService();

  List<UserModel> _searchResults = [];
  List<PostModel> _searchPostResults = [];
  bool _isSearching = false;
  String _lastQuery = '';
  UserModel? _currentUser;
  Timer? _debounceTimer;

  // Danh sách ID người dùng mà người dùng hiện tại đã gửi lời mời
  final Set<String> _sentRequestUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      final user = await _authService.getUserProfile(uid);
      if (mounted) {
        setState(() => _currentUser = user);
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchPostResults = [];
        _lastQuery = '';
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _lastQuery = query;
    });

    try {
      // 1. Tìm người dùng thật (Đã fix hỗ trợ email có @ và không dấu)
      final userResults = await _friendService.searchUsersByEmail(query);

      // 2. Tìm bài viết thật chứa từ khóa hoặc tác giả
      List<PostModel> postResults = [];
      try {
        final cleanTag = query.toLowerCase();
        final postSnap = await FirebaseFirestore.instance
            .collection('posts')
            .limit(50)
            .get();

        postResults = postSnap.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((p) =>
                p.content.toLowerCase().contains(cleanTag) ||
                p.authorName.toLowerCase().contains(cleanTag))
            .toList();
        postResults.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {}

      if (mounted) {
        setState(() {
          _searchResults = userResults;
          _searchPostResults = postResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tìm kiếm: $e'),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(UserModel targetUser) async {
    setState(() {
      _sentRequestUserIds.add(targetUser.uid);
    });

    try {
      await _friendService.sendFriendRequest(targetUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi lời mời kết bạn tới ${targetUser.displayName}'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadCurrentUser();
      }
    } catch (e) {
      setState(() {
        _sentRequestUserIds.remove(targetUser.uid);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    try {
      await _friendService.acceptFriendRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã kết bạn với ${request.senderName}'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadCurrentUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(FriendRequestModel request) async {
    try {
      await _friendService.rejectFriendRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối lời mời kết bạn.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tìm kiếm & Khám phá',
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSecondary : AppColors.lightLavender,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                const Tab(text: 'Khám phá & Tìm kiếm'),
                Tab(
                  child: StreamBuilder<List<FriendRequestModel>>(
                    stream: _friendService.getReceivedFriendRequestsStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Lời mời kết bạn'),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.coralDanger,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                count.toString(),
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchAndDiscoveryTab(isDark, bg, cardBg, textPrimary, textSecondary, borderColor),
          _buildRequestsTab(isDark, cardBg, textPrimary, textSecondary, borderColor),
        ],
      ),
    );
  }

  Widget _buildSearchAndDiscoveryTab(
    bool isDark,
    Color bg,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final hasActiveResults = _searchResults.isNotEmpty || _searchPostResults.isNotEmpty;

    return Column(
      children: [
        // Thanh nhập tìm kiếm chuẩn Figma
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkInputBg : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _performSearch(),
                    onChanged: _onSearchChanged,
                    style: TextStyle(fontSize: 14, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên (Hoàng Duy Mạnh) hoặc email...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _searchPostResults = [];
                                  _lastQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _performSearch,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.search_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Danh sách kết quả HOẶC Gợi ý kết bạn
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : hasActiveResults
                  ? _buildSearchResultsList(isDark, cardBg, textPrimary, textSecondary, borderColor)
                  : _searchController.text.isNotEmpty && _lastQuery.isNotEmpty
                      ? _buildEmptySearchState(textPrimary, textSecondary)
                      : _buildDiscoveryFeed(isDark, cardBg, textPrimary, textSecondary, borderColor),
        ),
      ],
    );
  }

  /// Khung hiển thị Gợi ý kết bạn & Bài viết thật
  Widget _buildDiscoveryFeed(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Tiêu đề Gợi ý kết bạn
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                'Có thể bạn quen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Danh sách gợi ý người dùng từ Firestore
        StreamBuilder<List<UserModel>>(
          stream: _friendService.getSuggestedUsersStream(),
          builder: (context, snapshot) {
            final realUsers = snapshot.data ?? [];
            if (realUsers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Center(
                  child: Text(
                    'Đang tìm kiếm người dùng mới trên SupaChat...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: realUsers.map((u) {
                return _buildUserCard(u, isDark, cardBg, textPrimary, textSecondary, borderColor);
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 16),

        // Tiêu đề Bài viết mới nhất
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.tealAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.dynamic_feed_rounded, size: 16, color: AppColors.tealAccent),
              ),
              const SizedBox(width: 10),
              Text(
                'Bài viết cộng đồng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Danh sách bài viết thật từ Firestore
        StreamBuilder<List<PostModel>>(
          stream: _postService.getPostsStream(),
          builder: (context, snapshot) {
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Center(
                  child: Text(
                    'Chưa có bài viết nào trên bảng tin.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: posts.take(5).map((post) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarWidget(photoUrl: post.authorAvatar, name: post.authorName, radius: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                                Text(
                                  post.privacy == 'friends' ? 'Chỉ bạn bè' : 'Công khai',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (post.content.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(post.content, style: TextStyle(fontSize: 14, color: textPrimary)),
                      ],
                      if (post.musicTrackTitle != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSecondary : AppColors.lightLavender,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note_rounded, size: 16, color: AppColors.primaryLight),
                              const SizedBox(width: 6),
                              Text(
                                '${post.musicTrackTitle} • ${post.musicTrackArtist ?? ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchResultsList(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Kết quả người dùng
        if (_searchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Người dùng (${_searchResults.length})',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          ..._searchResults.map((targetUser) {
            return _buildUserCard(targetUser, isDark, cardBg, textPrimary, textSecondary, borderColor);
          }),
          const SizedBox(height: 16),
        ],

        // 2. Kết quả bài viết
        if (_searchPostResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Bài viết (${_searchPostResults.length})',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          ..._searchPostResults.map((post) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarWidget(photoUrl: post.authorAvatar, name: post.authorName, radius: 16),
                      const SizedBox(width: 8),
                      Text(post.authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(post.content, style: TextStyle(fontSize: 14, color: textPrimary)),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildUserCard(
    UserModel targetUser,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final myFriends = _currentUser?.friendsList ?? [];
    final isFriend = myFriends.contains(targetUser.uid);
    final hasSentRequest = _sentRequestUserIds.contains(targetUser.uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        children: [
          AvatarWidget(
            photoUrl: targetUser.photoUrl,
            name: targetUser.displayName,
            radius: 24,
            showOnlineStatus: true,
            isOnline: targetUser.isOnline,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetUser.displayName,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  targetUser.email.isNotEmpty ? targetUser.email : '@${targetUser.uid.substring(0, 8)}',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isFriend)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(receiverUser: targetUser)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Nhắn tin',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else if (hasSentRequest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondary : AppColors.lightLavender,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Đã gửi lời mời',
                style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          else
            GestureDetector(
              onTap: () => _sendFriendRequest(targetUser),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Kết bạn',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 38, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy kết quả cho "$_lastQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy thử tìm kiếm bằng Email chính xác của bạn bè (ví dụ: manh11725@gmail.com) hoặc Tên đầy đủ (ví dụ: Hoàng Duy Mạnh).',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
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
                  Icon(Icons.mail_outline_rounded, size: 64, color: textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'Không có lời mời kết bạn nào',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Khi có người gửi lời mời kết bạn, danh sách sẽ hiển thị tại đây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final request = requests[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                children: [
                  AvatarWidget(
                    photoUrl: request.senderPhotoUrl,
                    name: request.senderName,
                    radius: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.senderName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${request.senderEmail.split('@').first}',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _acceptRequest(request),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Chấp nhận',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _rejectRequest(request),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSecondary : AppColors.lightLavender,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Từ chối',
                        style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
