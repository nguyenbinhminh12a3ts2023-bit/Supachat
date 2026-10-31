import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/music_tracks.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import '../services/audio_player_service.dart';
import '../services/post_service.dart';
import 'avatar_widget.dart';

/// Modal chi tiết bài viết hoàn chỉnh: Xem ảnh, nghe nhạc, thả tim & bình luận trực tiếp
class PostDetailModal extends StatefulWidget {
  final PostModel initialPost;

  const PostDetailModal({super.key, required this.initialPost});

  static Future<void> show(
    BuildContext context, {
    PostModel? post,
    String? postId,
    String? fallbackAuthor,
    String? fallbackContent,
    String? fallbackImage,
  }) async {
    PostModel? targetPost = post;

    if (targetPost == null && postId != null && postId.isNotEmpty) {
      // 1. Tìm trong cache
      final cachedIdx = PostService.cachedPosts.indexWhere((p) => p.id == postId);
      if (cachedIdx >= 0) {
        targetPost = PostService.cachedPosts[cachedIdx];
      } else {
        // 2. Tải từ Firestore
        try {
          final doc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
          if (doc.exists) {
            targetPost = PostModel.fromFirestore(doc);
          }
        } catch (_) {}
      }
    }

    // 3. Nếu chưa tìm được theo ID, tìm theo nội dung/tác giả trong cache hoặc Firestore
    if (targetPost == null && fallbackContent != null && fallbackContent.isNotEmpty) {
      final cleanContent = fallbackContent.trim();
      final cachedMatch = PostService.cachedPosts.firstWhere(
        (p) => p.content.trim() == cleanContent || (fallbackImage != null && p.imageUrl == fallbackImage),
        orElse: () => PostModel(
          id: postId ?? 'shared_temp',
          authorId: '',
          authorName: fallbackAuthor ?? 'SupaChat Member',
          content: fallbackContent,
          imageUrl: fallbackImage,
          createdAt: DateTime.now(),
          likes: [],
        ),
      );
      targetPost = cachedMatch;
    }

    targetPost ??= PostModel(
      id: postId ?? 'shared_temp',
      authorId: '',
      authorName: fallbackAuthor ?? 'SupaChat Member',
      content: fallbackContent ?? 'Nội dung bài viết',
      imageUrl: fallbackImage,
      createdAt: DateTime.now(),
      likes: [],
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostDetailModal(initialPost: targetPost!),
    );
  }

  @override
  State<PostDetailModal> createState() => _PostDetailModalState();
}

class _PostDetailModalState extends State<PostDetailModal> {
  final PostService _postService = PostService();
  final TextEditingController _commentCtrl = TextEditingController();
  late PostModel _post;
  bool _isPlayingMusic = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Widget _buildSafeImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => Container(
            height: 200,
            color: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.broken_image_rounded, size: 40),
          ),
        );
      } catch (_) {
        return Container(
          height: 200,
          color: AppColors.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.broken_image_rounded, size: 40),
        );
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, _, _) => Container(
        height: 200,
        color: AppColors.primary.withValues(alpha: 0.15),
        child: const Icon(Icons.broken_image_rounded, size: 40),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E202C) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUserModel?.uid ?? authProvider.firebaseUser?.uid ?? '';
    final isLiked = _post.isLikedBy(currentUserId);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Thanh kéo drag handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),

              // Header: Thông tin tác giả & Nút Đóng
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    AvatarWidget(
                      photoUrl: _post.authorAvatar,
                      name: _post.authorName,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _post.authorName,
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
                                _formatTimeAgo(_post.createdAt),
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _post.privacy == 'friends' ? Icons.people_alt_rounded : Icons.public,
                                size: 12,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _post.privacy == 'friends' ? 'Bạn bè' : 'Công khai',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 16),

              // Thân bài viết có thể cuộn
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    // Nội dung văn bản
                    if (_post.content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          _post.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: textPrimary,
                          ),
                        ),
                      ),

                    // Nhạc đính kèm nếu có
                    if (_post.musicTrackTitle != null && _post.musicTrackTitle!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.brandGradient,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  _isPlayingMusic ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: () {
                                  if (_post.musicTrackUrl != null) {
                                    if (_isPlayingMusic) {
                                      AudioPlayerService.instance.stopTrack();
                                      setState(() => _isPlayingMusic = false);
                                    } else {
                                      AudioPlayerService.instance.playTrack(
                                        MusicTrack(
                                          id: _post.id,
                                          title: _post.musicTrackTitle!,
                                          artist: _post.musicTrackArtist ?? 'Nghệ sĩ V-Pop',
                                          audioUrl: _post.musicTrackUrl!,
                                          coverUrl: '',
                                          duration: '03:45',
                                        ),
                                      );
                                      setState(() => _isPlayingMusic = true);
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post.musicTrackTitle!,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _post.musicTrackArtist ?? 'Nghệ sĩ V-Pop',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),

                    // Hình ảnh bài viết
                    if (_post.imageUrl != null && _post.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildSafeImage(_post.imageUrl!),
                      ),

                    const SizedBox(height: 14),

                    // Action bar: Thả tim & Số bình luận
                    Row(
                      children: [
                        // Nút thả tim
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            if (currentUserId.isEmpty || _post.id.startsWith('shared_temp')) return;
                            await _postService.toggleLikePost(_post.id, currentUserId);
                            setState(() {
                              final likes = List<String>.from(_post.likes);
                              if (isLiked) {
                                likes.remove(currentUserId);
                              } else {
                                likes.add(currentUserId);
                              }
                              _post = _post.copyWith(likes: likes);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isLiked ? AppColors.coralDanger : textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_post.likes.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isLiked ? AppColors.coralDanger : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Số bình luận
                        Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: textSecondary, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '${_post.commentsCount}',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Tiêu đề phần bình luận
                    Text(
                      'Bình luận',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 10),

                    // Danh sách bình luận thời gian thực
                    if (!_post.id.startsWith('shared_temp'))
                      StreamBuilder<List<CommentModel>>(
                        stream: _postService.getCommentsStream(_post.id),
                        builder: (context, snapshot) {
                          final comments = snapshot.data ?? [];
                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'Chưa có bình luận nào. Hãy gửi lời bình đầu tiên!',
                                  style: TextStyle(fontSize: 13, color: textSecondary),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final comment = comments[idx];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AvatarWidget(
                                    photoUrl: comment.authorAvatar,
                                    name: comment.authorName,
                                    radius: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                                              ),
                                              Text(
                                                _formatTimeAgo(comment.createdAt),
                                                style: TextStyle(fontSize: 10, color: textSecondary),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment.content,
                                            style: TextStyle(fontSize: 13, color: textPrimary),
                                          ),
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () {
                                              final replyPrefix = '@${comment.authorName} ';
                                              _commentCtrl.text = replyPrefix;
                                              _commentCtrl.selection = TextSelection.fromPosition(
                                                TextPosition(offset: replyPrefix.length),
                                              );
                                            },
                                            child: const Text(
                                              'Trả lời',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
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

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Ô nhập bình luận ở đáy modal
              Container(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        style: TextStyle(fontSize: 14, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Bình luận về bài viết này...',
                          hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                          filled: true,
                          fillColor: isDark ? AppColors.darkInputBg : AppColors.inputBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: () async {
                          final text = _commentCtrl.text.trim();
                          if (text.isEmpty || _post.id.startsWith('shared_temp')) return;
                          _commentCtrl.clear();
                          await _postService.addComment(postId: _post.id, content: text);
                          setState(() {
                            _post = _post.copyWith(commentsCount: _post.commentsCount + 1);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
