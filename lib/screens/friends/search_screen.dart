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

/// Màn hình Tìm kiếm đa năng:
/// - Tìm kiếm người dùng thật theo Tên / Email / Handle
/// - Tìm kiếm bài viết thật theo từ khóa / hashtag
/// - Gợi ý kết bạn từ người dùng thật trên Firestore
/// - Quản lý danh sách lời mời kết bạn
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
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

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _lastQuery = query;
    });

    try {
      // 1. Tìm người dùng thật
      final userResults = await _friendService.searchUsersByEmail(query);

      // 2. Tìm bài viết thật chứa từ khóa hoặc hashtag
      List<PostModel> postResults = [];
      try {
        final cleanTag = query.toLowerCase();
        final postSnap = await FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        postResults = postSnap.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((p) =>
                p.content.toLowerCase().contains(cleanTag) ||
                p.authorName.toLowerCase().contains(cleanTag))
            .toList();
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
          SnackBar(content: Text('Lỗi tìm kiếm: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(UserModel targetUser) async {
    try {
      await _friendService.sendFriendRequest(targetUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi lời mời kết bạn tới ${targetUser.displayName}'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadCurrentUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.success,
          ),
        );
        await _loadCurrentUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _rejectRequest(FriendRequestModel request) async {
    try {
      await _friendService.rejectFriendRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối lời mời kết bạn.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm & Khám phá'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
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
                            color: AppColors.primary,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchAndDiscoveryTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildSearchAndDiscoveryTab() {
    final hasActiveResults = _searchResults.isNotEmpty || _searchPostResults.isNotEmpty;

    return Column(
      children: [
        // Thanh nhập tìm kiếm
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
                  onChanged: (val) {
                    if (val.isEmpty && hasActiveResults) {
                      setState(() {
                        _searchResults = [];
                        _searchPostResults = [];
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm người dùng, email, bài viết...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryLight),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _searchPostResults = [];
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.logoGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  onPressed: _performSearch,
                ),
              ),
            ],
          ),
        ),

        // Kết quả tìm kiếm HOẶC Gợi ý kết bạn & Bài viết gần đây
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : hasActiveResults
                  ? _buildSearchResultsList()
                  : _searchController.text.isNotEmpty && _lastQuery.isNotEmpty
                      ? _buildEmptySearchState()
                      : _buildDiscoveryFeed(),
        ),
      ],
    );
  }

  /// Khung hiển thị Gợi ý kết bạn & Bài viết thật
  Widget _buildDiscoveryFeed() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // --- 1. Header Gợi ý kết bạn ---
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.electricBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.electricBlue),
            ),
            const SizedBox(width: 10),
            const Text(
              'Gợi ý kết bạn',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Danh sách gợi ý người dùng từ Firestore
        StreamBuilder<List<UserModel>>(
          stream: _friendService.getSuggestedUsersStream(),
          builder: (context, snapshot) {
            final realUsers = snapshot.data ?? [];
            if (realUsers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'Chưa có người dùng nào khác trên hệ thống.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: realUsers.map((u) {
                final isFriend = _currentUser?.friendsList.contains(u.uid) == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(photoUrl: u.photoUrl, name: u.displayName, radius: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '@${u.email.split('@').first}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            if (u.bio?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  u.bio!,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFriend ? AppColors.accentGreen : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: isFriend ? null : () => _sendFriendRequest(u),
                        child: Text(
                          isFriend ? 'Bạn bè' : 'Kết bạn',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        // --- 2. Header Bài viết gần đây trên hệ thống ---
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.dynamic_feed_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Text(
              'Bài viết mới nhất',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Danh sách bài viết thật từ Firestore
        StreamBuilder<List<PostModel>>(
          stream: _postService.getPostsStream(),
          builder: (context, snapshot) {
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'Chưa có bài viết nào trên bảng tin.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: posts.take(5).map((post) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
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
                                Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  post.privacy == 'friends' ? 'Chỉ bạn bè' : 'Công khai',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (post.content.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(post.content, style: const TextStyle(fontSize: 14)),
                      ],
                      if (post.musicTrackTitle != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                '${post.musicTrackTitle} • ${post.musicTrackArtist ?? ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
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

  Widget _buildSearchResultsList() {
    final myFriends = _currentUser?.friendsList ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Kết quả người dùng
        if (_searchResults.isNotEmpty) ...[
          const Text(
            'Người dùng',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ..._searchResults.map((targetUser) {
            final isFriend = myFriends.contains(targetUser.uid);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  AvatarWidget(
                    photoUrl: targetUser.photoUrl,
                    name: targetUser.displayName,
                    radius: 22,
                    showOnlineStatus: true,
                    isOnline: targetUser.isOnline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(targetUser.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('@${targetUser.email.split('@').first}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFriend ? AppColors.accentGreen : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: isFriend
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatScreen(receiverUser: targetUser)),
                            );
                          }
                        : () => _sendFriendRequest(targetUser),
                    child: Text(
                      isFriend ? 'Nhắn tin' : 'Kết bạn',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 2. Kết quả bài viết
        if (_searchPostResults.isNotEmpty) ...[
          const Text(
            'Bài viết',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ..._searchPostResults.map((post) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarWidget(photoUrl: post.authorAvatar, name: post.authorName, radius: 16),
                      const SizedBox(width: 8),
                      Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(post.content, style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy kết quả nào cho "$_lastQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy thử tìm kiếm theo tên hoặc email của bạn bè.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
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
                  Icon(Icons.mail_outline_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Không có lời mời kết bạn nào',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Khi có người gửi lời mời kết bạn, bạn sẽ thấy danh sách ở đây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, index) => const Divider(color: AppColors.divider),
          itemBuilder: (context, index) {
            final request = requests[index];

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AvatarWidget(
                photoUrl: request.senderPhotoUrl,
                name: request.senderName,
                radius: 24,
              ),
              title: Text(
                request.senderName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                '@${request.senderEmail.split('@').first}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 34),
                    ),
                    onPressed: () => _acceptRequest(request),
                    child: const Text('Chấp nhận', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: const Size(0, 34),
                    ),
                    onPressed: () => _rejectRequest(request),
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
}
