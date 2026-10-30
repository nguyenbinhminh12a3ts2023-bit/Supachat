import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/music_tracks.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/post_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/avatar_widget.dart';

/// Màn hình Đăng bài viết mới (Create Post)
class CreatePostScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;

  const CreatePostScreen({super.key, this.onPostSuccess});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final PostService _postService = PostService();
  final StorageService _storageService = StorageService();

  Uint8List? _selectedImageBytes;
  MusicTrack? _selectedMusic;
  String _privacy = 'public'; // 'public' | 'friends'
  bool _isPosting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e'), backgroundColor: AppColors.coralDanger),
        );
      }
    }
  }

  void _showMusicSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.music_note_rounded, color: AppColors.primaryLight, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Đính kèm bài hát vào bài viết',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: MusicTrackLibrary.tracks.length,
                  separatorBuilder: (_, _) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (ctx, index) {
                    final track = MusicTrackLibrary.tracks[index];
                    final isPlayingThis = AudioPlayerService.instance.currentTrack?.id == track.id &&
                        AudioPlayerService.instance.isPlaying;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          track.coverUrl,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 46,
                            height: 46,
                            color: AppColors.primary,
                            child: const Icon(Icons.music_note, color: Colors.white),
                          ),
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isPlayingThis ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                              color: AppColors.primaryLight,
                              size: 28,
                            ),
                            onPressed: () async {
                              if (isPlayingThis) {
                                await AudioPlayerService.instance.pauseTrack();
                              } else {
                                await AudioPlayerService.instance.playTrack(track);
                              }
                              setSheetState(() {});
                            },
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedMusic?.id == track.id ? AppColors.accentGreen : AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedMusic = track;
                              });
                              Navigator.pop(ctx);
                            },
                            child: Text(_selectedMusic?.id == track.id ? 'Đã chọn' : 'Chọn'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ai có thể xem bài viết này?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.public, color: AppColors.primary, size: 22),
              ),
              title: const Text('Công khai', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Bất kỳ ai trên SupaChat đều có thể xem bài viết này', style: TextStyle(fontSize: 12)),
              trailing: _privacy == 'public'
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _privacy = 'public');
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded, color: AppColors.accentGreen, size: 22),
              ),
              title: const Text('Bạn bè', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Chỉ những người đã kết bạn với bạn mới có thể xem', style: TextStyle(fontSize: 12)),
              trailing: _privacy == 'friends'
                  ? const Icon(Icons.check_circle, color: AppColors.accentGreen)
                  : null,
              onTap: () {
                setState(() => _privacy = 'friends');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung bài viết hoặc thêm ảnh!'),
          backgroundColor: AppColors.coralDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      String? imageUrl;
      if (_selectedImageBytes != null) {
        imageUrl = await _storageService.uploadPostImageBytes(bytes: _selectedImageBytes!);
      }

      await _postService.createPost(
        content: content,
        imageUrl: imageUrl,
        musicTrack: _selectedMusic,
        privacy: _privacy,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đăng bài viết thành công!'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _contentController.clear();
        setState(() {
          _selectedImageBytes = null;
          _selectedMusic = null;
        });

        widget.onPostSuccess?.call();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi đăng bài: $e'),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
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
    final user = authProvider.currentUserModel;
    final displayName = user?.displayName ?? 'Bạn';
    final avatarUrl = user?.photoUrl;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Tạo bài viết mới',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              onPressed: _isPosting ? null : _handlePost,
              child: _isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Đăng bài', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin tác giả
                    Row(
                      children: [
                        AvatarWidget(photoUrl: avatarUrl, name: displayName, radius: 24),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: _showPrivacySelector,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSecondary : AppColors.lightLavender,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _privacy == 'public' ? Icons.public : Icons.people_alt_rounded,
                                      size: 13,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _privacy == 'public' ? 'Công khai' : 'Bạn bè',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 15,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nhập nội dung bài viết
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      minLines: 4,
                      style: TextStyle(fontSize: 16, color: textPrimary, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Bạn đang nghĩ gì thế?... Hãy chia sẻ khoảnh khắc của bạn!',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 16),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thẻ bài hát nếu được đính kèm
                    if (_selectedMusic != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _selectedMusic!.coverUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.music_note_rounded, size: 16, color: AppColors.primaryLight),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _selectedMusic!.title,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _selectedMusic!.artist,
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                              onPressed: () => setState(() => _selectedMusic = null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Xem trước ảnh nếu có
                    if (_selectedImageBytes != null) ...[
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: double.infinity,
                              height: 280,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: IconButton(
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              onPressed: () => setState(() => _selectedImageBytes = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Toolbar đính kèm phía dưới
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor, width: 0.8)),
              ),
              child: Row(
                children: [
                  Text(
                    'Thêm vào bài viết:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  const Spacer(),
                  // Nút ảnh
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: AppColors.accentGreen, size: 26),
                    tooltip: 'Đính kèm ảnh',
                    onPressed: _pickImage,
                  ),
                  // Nút nhạc
                  IconButton(
                    icon: Icon(
                      Icons.music_note_rounded,
                      color: _selectedMusic != null ? AppColors.primary : AppColors.primaryLight,
                      size: 26,
                    ),
                    tooltip: 'Đính kèm nhạc',
                    onPressed: _showMusicSelector,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
