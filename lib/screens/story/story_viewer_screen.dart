import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/music_tracks.dart';
import '../../models/story_model.dart';
import '../../models/user_model.dart';
import '../../services/audio_player_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/story_service.dart';
import '../../utils/download_helper.dart';
import '../../widgets/avatar_widget.dart';
import '../chat/chat_screen.dart';

/// Trình xem Tin (Story Viewer) chuẩn Instagram / Facebook
class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;
  final String currentUserId;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.currentUserId,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  final StoryService _storyService = StoryService();
  final TextEditingController _replyController = TextEditingController();
  final Set<String> _likedStoryIds = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goToNextStory();
        }
      });

    _loadCurrentStory();
  }

  void _loadCurrentStory() {
    if (_currentIndex >= widget.stories.length) {
      Navigator.pop(context);
      return;
    }

    final story = widget.stories[_currentIndex];
    final myUid = widget.currentUserId.isNotEmpty ? widget.currentUserId : (_storyService.currentUserId ?? '');
    if (story.isLikedBy(myUid)) {
      _likedStoryIds.add(story.id);
    }

    // Đánh dấu đã xem
    _storyService.markStoryAsViewed(story.id, widget.currentUserId);

    // Phát nhạc nếu story có nhạc
    if (story.musicTrackUrl != null && story.musicTrackUrl!.isNotEmpty) {
      final track = MusicTrack(
        id: story.id,
        title: story.musicTrackTitle ?? 'Story Music',
        artist: story.musicTrackArtist ?? 'SupaChat Music',
        audioUrl: story.musicTrackUrl!,
        coverUrl: story.userAvatar ?? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
        duration: '00:30',
      );
      AudioPlayerService.instance.playTrack(track, startSeconds: story.musicStartTime);
    }

    _progressController.stop();
    _progressController.reset();
    _progressController.forward();
  }

  void _goToNextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _goToPrevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadCurrentStory();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pause() {
    _progressController.stop();
  }

  void _resume() {
    _progressController.forward();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _progressController.dispose();
    AudioPlayerService.instance.stopTrack();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Widget _buildStoryImage(String url, Color bgColor) {
    Widget imageWidget;
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, error, stack) => _buildFallback(bgColor),
        );
      } catch (_) {
        return _buildFallback(bgColor);
      }
    } else {
      imageWidget = Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, error, stack) => _buildFallback(bgColor),
      );
    }

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: imageWidget,
    );
  }

  Widget _buildFallback(Color bgColor) {
    return Container(
      color: bgColor,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
      ),
    );
  }

  Future<void> _deleteStory(StoryModel story) async {
    _pause();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa tin?', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc muốn xóa tin này không?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storyService.deleteStory(story.id);
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      _resume();
    }
  }

  Future<void> _sendReplyToStory(StoryModel story, String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _pause();
    _replyController.clear();

    final chatService = ChatService();
    final storyPrefix = story.caption.isNotEmpty ? ' [Story: "${story.caption}"]' : ' [Story]';
    final messageText = '💬 Đã phản hồi tin của bạn$storyPrefix: $cleanText';

    try {
      await chatService.sendMessage(
        receiverId: story.userId,
        text: messageText,
        mediaUrl: story.imageUrl,
      );
    } catch (e) {
      debugPrint('Lỗi gửi phản hồi story: $e');
    }

    final targetUser = await AuthService().getUserProfile(story.userId) ??
        UserModel(
          uid: story.userId,
          displayName: story.userName,
          email: '',
          photoUrl: story.userAvatar,
          createdAt: DateTime.now(),
        );

    if (mounted) {
      AudioPlayerService.instance.stopTrack();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(receiverUser: targetUser),
        ),
      );
    }
  }

  Future<void> _toggleHeartStory(StoryModel story) async {
    final myUid = widget.currentUserId.isNotEmpty ? widget.currentUserId : (_storyService.currentUserId ?? '');
    final wasLiked = _likedStoryIds.contains(story.id) || story.isLikedBy(myUid);
    final nowLiked = !wasLiked;

    setState(() {
      if (nowLiked) {
        _likedStoryIds.add(story.id);
      } else {
        _likedStoryIds.remove(story.id);
      }
    });

    await _storyService.toggleLikeStory(story.id, myUid);

    if (nowLiked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thả ❤️ cho tin của ${story.userName}!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      final chatService = ChatService();
      try {
        await chatService.sendMessage(
          receiverId: story.userId,
          text: '❤️ Đã thả tim cho tin của bạn!',
          mediaUrl: story.imageUrl,
        );
      } catch (_) {}
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã bỏ thích tin của ${story.userName}.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showViewersBottomSheet(BuildContext context, StoryModel story) {
    _pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            color: Color(0xFF141724),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Thanh kéo
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Tiêu đề & Đếm
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_rounded, color: AppColors.tealAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Người đã xem (${story.viewers.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Danh sách người xem
              Expanded(
                child: story.viewers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility_off_outlined, size: 48, color: Colors.white38),
                            SizedBox(height: 12),
                            Text(
                              'Chưa có ai xem tin này',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tin của bạn sẽ hiển thị với bạn bè trong vòng 24 giờ.',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : FutureBuilder<List<UserModel>>(
                        future: _fetchViewers(story.viewers),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final viewers = snapshot.data ?? [];
                          if (viewers.isEmpty) {
                            return Center(
                              child: Text(
                                '${story.viewers.length} người đã xem tin',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: viewers.length,
                            itemBuilder: (context, idx) {
                              final user = viewers[idx];
                              return ListTile(
                                leading: AvatarWidget(
                                  photoUrl: user.photoUrl,
                                  name: user.displayName,
                                  radius: 22,
                                  showOnlineStatus: true,
                                  isOnline: user.isActuallyOnline,
                                ),
                                title: Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  user.isActuallyOnline ? 'Đang hoạt động' : user.onlineStatusText,
                                  style: TextStyle(
                                    color: user.isActuallyOnline ? AppColors.tealAccent : Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryLight, size: 20),
                                  tooltip: 'Nhắn tin',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(receiverUser: user),
                                      ),
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
        );
      },
    ).then((_) => _resume());
  }

  Future<List<UserModel>> _fetchViewers(List<String> uids) async {
    final futures = uids.map((uid) => AuthService().getUserProfile(uid));
    final results = await Future.wait(futures);
    return results.whereType<UserModel>().toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.stories.length) return const SizedBox.shrink();
    final story = widget.stories[_currentIndex];
    final myUid = widget.currentUserId.isNotEmpty ? widget.currentUserId : (_storyService.currentUserId ?? '');
    final isMyStory = story.userId == myUid;
    final bgColor = _hexToColor(story.backgroundColor);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _pause(),
          onTapUp: (details) {
            _resume();
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.localPosition.dx < screenWidth * 0.35) {
              _goToPrevStory();
            } else {
              _goToNextStory();
            }
          },
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -200 && isMyStory) {
              _showViewersBottomSheet(context, story);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Nền Story (Full Screen Canvas: Toàn màn hình)
              Positioned.fill(
                child: story.imageUrl != null && story.imageUrl!.isNotEmpty
                    ? _buildStoryImage(story.imageUrl!, bgColor)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              bgColor,
                              bgColor.withValues(alpha: 0.82),
                              const Color(0xFF10121C),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
              ),

              // Lớp phủ bóng gradient để text và header nổi bật
              if (story.imageUrl != null && story.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

              // 2. Chữ hiển thị đúng vị trí người dùng đã kéo thả
              if (story.caption.isNotEmpty)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment(story.textPositionX, story.textPositionY),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: story.textStyle == 'normal'
                          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                          : const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: story.textStyle == 'darkPill'
                          ? BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white24),
                            )
                          : story.textStyle == 'lightPill'
                              ? BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                                  ],
                                )
                              : null,
                      child: Text(
                        story.caption,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: story.textStyle == 'lightPill' ? Colors.black87 : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: story.textStyle == 'normal'
                              ? const [
                                  Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 2)),
                                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Stickers nếu có (Hiển thị đúng vị trí người dùng đã kéo thả)
              if (story.stickers.isNotEmpty)
                ...story.stickers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final st = entry.value;
                  final posX = idx < story.stickerPositionsX.length ? story.stickerPositionsX[idx] : 0.0;
                  final posY = idx < story.stickerPositionsY.length ? story.stickerPositionsY[idx] : (-0.4 + idx * 0.12).clamp(-0.8, 0.8);
                  return Positioned.fill(
                    child: Align(
                      alignment: Alignment(posX, posY),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white38),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Text(
                          st,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              // 4. Top Header: Progress bars & User Info (Định vị cố định ở đỉnh màn hình)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Thanh tiến trình
                        Row(
                          children: List.generate(widget.stories.length, (idx) {
                            return Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white30,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: idx < _currentIndex
                                    ? Container(color: Colors.white)
                                    : idx == _currentIndex
                                        ? AnimatedBuilder(
                                            animation: _progressController,
                                            builder: (ctx, child) {
                                              return FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: _progressController.value,
                                                child: Container(color: Colors.white),
                                              );
                                            },
                                          )
                                        : const SizedBox.shrink(),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),

                        // User Info row (Figma exact: Avatar, Name, Music, Delete/Close)
                        Row(
                          children: [
                            AvatarWidget(
                              photoUrl: story.userAvatar,
                              name: story.userName,
                              radius: 18,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  story.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                  ),
                                ),
                                if (story.musicTrackTitle != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.music_note_rounded, color: AppColors.primaryLight, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${story.musicTrackTitle} • ${story.musicTrackArtist ?? ''}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const Spacer(),

                            // Download story image button
                            if (story.imageUrl != null && story.imageUrl!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                                tooltip: 'Tải tin về máy',
                                onPressed: () async {
                                  _pause();
                                  await DownloadHelper.downloadImage(story.imageUrl!);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Đang tải hình ảnh tin về thiết bị...'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                  _resume();
                                },
                              ),

                            // Delete button if my story
                            if (isMyStory)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                tooltip: 'Xóa tin',
                                onPressed: () => _deleteStory(story),
                              ),

                            // Close button
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Quick Reply Bottom Bar chuẩn Instagram / Facebook
              // Nếu là tin của bạn: Hiển thị thanh đếm lượt xem "👁️ Tin của bạn"
              // Nếu là tin của người khác: Hiển thị ô "Gửi tin nhắn..." + Nút Thả tim ❤️
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: isMyStory
                      ? GestureDetector(
                          onTap: () => _showViewersBottomSheet(context, story),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.visibility_outlined, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '${story.viewers.length} người đã xem',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 18),
                              ],
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _replyController,
                                        onTap: () => _pause(),
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: const InputDecoration(
                                          hintText: 'Gửi tin nhắn...',
                                          hintStyle: TextStyle(color: Colors.white70, fontSize: 14),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          filled: false,
                                          fillColor: Colors.transparent,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                          isDense: true,
                                        ),
                                        onSubmitted: (val) => _sendReplyToStory(story, val),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                      tooltip: 'Gửi phản hồi',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _sendReplyToStory(story, _replyController.text),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Nút thả tim (Viền trong suốt khi chưa tim, đỏ hồng khi đã tim)
                            Builder(
                              builder: (ctx) {
                                final isLiked = _likedStoryIds.contains(story.id) || story.isLikedBy(myUid);
                                return InkWell(
                                  onTap: () => _toggleHeartStory(story),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isLiked
                                          ? AppColors.coralDanger.withValues(alpha: 0.25)
                                          : Colors.white.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isLiked ? AppColors.coralDanger : Colors.white24,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Icon(
                                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isLiked ? AppColors.coralDanger : Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
