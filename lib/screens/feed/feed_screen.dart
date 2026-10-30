import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/music_tracks.dart';
import '../../models/post_model.dart';
import '../../models/story_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/post_service.dart';
import '../../services/story_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/supa_chat_logo.dart';
import '../story/create_story_screen.dart';
import '../story/story_viewer_screen.dart';
import 'create_post_screen.dart';

/// Màn hình Bảng tin SupaChat (Home Feed)
class FeedScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMessages;

  const FeedScreen({super.key, this.onNavigateToMessages});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PostService _postService = PostService();
  final StoryService _storyService = StoryService();

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  void _showCommentsSheet(BuildContext context, PostModel post, String currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bình luận (${post.commentsCount})',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Danh sách bình luận
              Expanded(
                child: StreamBuilder<List<CommentModel>>(
                  stream: _postService.getCommentsStream(post.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          'Chưa có bình luận nào. Hãy là người đầu tiên!',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AvatarWidget(
                              photoUrl: comment.authorAvatar,
                              name: comment.authorName,
                              radius: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkInputBg : AppColors.inputBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          comment.authorName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Text(
                                          _formatTimeAgo(comment.createdAt),
                                          style: TextStyle(fontSize: 11, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment.content,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Nhập bình luận
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: TextStyle(fontSize: 14, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Viết bình luận...',
                          hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                          filled: true,
                          fillColor: isDark ? AppColors.darkInputBg : AppColors.inputBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                      onPressed: () async {
                        final text = commentController.text.trim();
                        if (text.isNotEmpty) {
                          commentController.clear();
                          await _postService.addComment(postId: post.id, content: text);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUserModel?.uid ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SupaChatIcon(size: 32),
            const SizedBox(width: 10),
            Text(
              'SupaChat',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded, color: textPrimary),
            tooltip: 'Tin nhắn',
            onPressed: widget.onNavigateToMessages,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: CustomScrollView(
            slivers: [
              // 1. Story Bar (Tin 24h)
              SliverToBoxAdapter(
                child: StreamBuilder<List<StoryModel>>(
                  stream: _storyService.getActiveStoriesStream(),
                  builder: (context, snapshot) {
                    final stories = snapshot.data ?? [];
                    final myStories = stories.where((s) => s.userId == currentUserId).toList();

                    return Container(
                      height: 108,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Vòng tròn Tin của bạn
                          _buildMyStoryCircle(myStories, isDark, textPrimary, textSecondary),

                          // Các Story của bạn bè / người khác
                          ...stories.where((s) => s.userId != currentUserId).map((story) {
                            final hasViewed = story.viewers.contains(currentUserId);
                            return _buildStoryItem(story, stories, hasViewed, isDark, textPrimary);
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: Divider(height: 1, thickness: 0.8),
              ),

              // 2. Post List (Bảng tin)
              StreamBuilder<List<PostModel>>(
                stream: _postService.getPostsStream(),
                builder: (context, snapshot) {
                  final posts = snapshot.hasData
                      ? snapshot.data!
                      : PostService.cachedPosts;

                  if (snapshot.connectionState == ConnectionState.waiting && posts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError && posts.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(child: Text('Lỗi tải bài viết: ${snapshot.error}')),
                    );
                  }

                  if (posts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.feed_outlined,
                                size: 64,
                                color: isDark ? AppColors.primaryLight.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Bảng tin chưa có bài viết nào',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hãy là người đầu tiên chia sẻ khoảnh khắc, cảm xúc hoặc một bài hát thật tuyệt vời!',
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
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Tạo bài viết ngay'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = posts[index];
                        return _buildPostCard(post, isDark, cardBg, textPrimary, textSecondary, borderColor, currentUserId);
                      },
                      childCount: posts.length,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyStoryCircle(
    List<StoryModel> myStories,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final hasActiveStory = myStories.isNotEmpty;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () {
          if (hasActiveStory) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoryViewerScreen(
                  stories: myStories,
                  currentUserId: user?.uid ?? '',
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasActiveStory
                        ? const LinearGradient(
                            colors: [AppColors.gradientStart, AppColors.gradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: hasActiveStory ? null : Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 1.5),
                  ),
                  child: AvatarWidget(
                    photoUrl: user?.photoUrl,
                    name: user?.displayName ?? 'Tôi',
                    radius: 28,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tin của bạn',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(
    StoryModel story,
    List<StoryModel> allStories,
    bool hasViewed,
    bool isDark,
    Color textPrimary,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () {
          final storyIndex = allStories.indexOf(story);
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryViewerScreen(
                stories: allStories,
                initialIndex: storyIndex >= 0 ? storyIndex : 0,
                currentUserId: authProvider.currentUserModel?.uid ?? '',
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasViewed
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: hasViewed
                    ? Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 1.5)
                    : null,
              ),
              child: AvatarWidget(
                photoUrl: story.userAvatar,
                name: story.userName,
                radius: 28,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                story.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
  }

  Widget _buildPostCard(
    PostModel post,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    String currentUserId,
  ) {
    final isLiked = post.isLikedBy(currentUserId);
    final hasMusic = post.musicTrackUrl != null && post.musicTrackUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tác giả & Action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                AvatarWidget(
                  photoUrl: post.authorAvatar,
                  name: post.authorName,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatTimeAgo(post.createdAt),
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            post.privacy == 'friends' ? Icons.people_alt_rounded : Icons.public,
                            size: 11,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            post.privacy == 'friends' ? 'Bạn bè' : 'Công khai',
                            style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.authorId == currentUserId)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, color: textSecondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    onSelected: (val) {
                      if (val == 'delete') {
                        _postService.deletePost(post.id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppColors.coralDanger, size: 20),
                            SizedBox(width: 8),
                            Text('Xóa bài viết', style: TextStyle(color: AppColors.coralDanger)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Nội dung văn bản
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                post.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: textPrimary,
                ),
              ),
            ),

          // Thẻ âm nhạc phát được (Real Playable Audio)
          if (hasMusic)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AnimatedBuilder(
                animation: AudioPlayerService.instance,
                builder: (context, _) {
                  final currentTrack = AudioPlayerService.instance.currentTrack;
                  final isPlayingThis = currentTrack?.audioUrl == post.musicTrackUrl &&
                      AudioPlayerService.instance.isPlaying;

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkInputBg : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPlayingThis ? AppColors.primary : borderColor,
                        width: isPlayingThis ? 1.5 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isPlayingThis ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.musicTrackTitle ?? 'Bản nhạc',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isPlayingThis ? AppColors.primary : textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                post.musicTrackArtist ?? 'SupaChat Music',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isPlayingThis ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          onPressed: () {
                            if (isPlayingThis) {
                              AudioPlayerService.instance.pauseTrack();
                            } else {
                              final track = MusicTrack(
                                id: post.musicTrackId ?? post.id,
                                title: post.musicTrackTitle ?? 'Nhạc bài viết',
                                artist: post.musicTrackArtist ?? 'SupaChat Music',
                                audioUrl: post.musicTrackUrl!,
                                coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
                                duration: '03:00',
                              );
                              AudioPlayerService.instance.playTrack(track);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Hình ảnh bài viết
          if (post.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),

          // Action row: Like, Comment, Share
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                // Nút Like
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isLiked ? AppColors.coralDanger : textSecondary,
                    size: 22,
                  ),
                  onPressed: () {
                    _postService.toggleLikePost(post.id, currentUserId);
                  },
                ),
                Text(
                  '${post.likes.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isLiked ? AppColors.coralDanger : textSecondary,
                  ),
                ),
                const SizedBox(width: 14),

                // Nút Comment
                IconButton(
                  icon: Icon(Icons.mode_comment_outlined, color: textSecondary, size: 20),
                  onPressed: () => _showCommentsSheet(context, post, currentUserId),
                ),
                Text(
                  '${post.commentsCount}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                const Spacer(),

                // Nút Share
                IconButton(
                  icon: Icon(Icons.share_outlined, color: textSecondary, size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép liên kết bài viết!'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
