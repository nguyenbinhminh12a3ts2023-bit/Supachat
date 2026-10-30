import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/music_tracks.dart';
import '../../models/story_model.dart';
import '../../services/audio_player_service.dart';
import '../../services/story_service.dart';
import '../../widgets/avatar_widget.dart';

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
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _buildFallback(bgColor),
        );
      } catch (_) {
        return _buildFallback(bgColor);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildFallback(bgColor),
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

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.stories.length) return const SizedBox.shrink();
    final story = widget.stories[_currentIndex];
    final isMyStory = story.userId == widget.currentUserId;
    final bgColor = _hexToColor(story.backgroundColor);

    return Scaffold(
      backgroundColor: Colors.black,
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
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
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
                            ],
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
                                        onSubmitted: (val) {
                                          _resume();
                                          if (val.trim().isNotEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Đã gửi phản hồi đến ${story.userName}'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Nút thả tim
                            InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã thả ❤️ cho tin của ${story.userName}!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                child: const Icon(Icons.favorite_rounded, color: AppColors.coralDanger, size: 22),
                              ),
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
