import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/music_tracks.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/storage_service.dart';
import '../../services/story_service.dart';
import '../../widgets/avatar_widget.dart';

enum StoryCreationMode { select, text, photo }

enum StoryTextStyle {
  neat('Gọn gàng'),
  casual('Bình thường'),
  stylish('Kiểu cách'),
  headline('Tiêu đề'),
  pill('Nổi bật');

  final String label;
  const StoryTextStyle(this.label);
}

class StoryStickerItem {
  final String text;
  Offset offset;
  StoryStickerItem({required this.text, this.offset = Offset.zero});
}

/// Màn hình Tạo Story 24h chuẩn giao diện Studio Facebook / Instagram
/// - Bước 1: Màn hình chọn [Tạo tin có ảnh hoặc video] hoặc [Tạo tin dạng văn bản]
/// - Bước 2A: Tạo tin văn bản với Trình xem trước (Live Preview), đổi phông chữ, bảng màu, thêm nhạc
/// - Bước 2B: Tạo tin có ảnh với xoay ảnh 90°, kéo thả chữ trên ảnh, thêm nhạc 20 bài V-Pop
/// - Thiết kế Responsive chuẩn xác cho cả Mobile và Web/Desktop
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final StoryService _storyService = StoryService();
  final StorageService _storageService = StorageService();
  final TextEditingController _textController = TextEditingController();

  StoryCreationMode _mode = StoryCreationMode.select;
  StoryTextStyle _selectedStyle = StoryTextStyle.neat;

  Uint8List? _selectedImageBytes;
  int _photoRotation = 0; // 0, 90, 180, 270

  MusicTrack? _selectedMusic;
  int _musicStartSeconds = 0;
  final List<StoryStickerItem> _stickerItems = [];
  bool _isUploading = false;

  // Vị trí kéo thả của Text Box trên ảnh
  Offset _textOffset = Offset.zero;

  // Bảng màu nền phong cách Facebook Story
  final List<String> _bgColors = [
    '#2E65F3', // Xanh Dương Facebook
    '#6C5CE7', // Tím SupaChat
    '#ED5565', // Đỏ Hồng
    '#00B894', // Xanh Ngọc
    '#AC5CD9', // Tím Lavender
    '#E17055', // Cam Hoàng Hôn
    '#1B1E2C', // Đen Midnight
  ];
  late String _selectedBgColor;

  static const List<String> _availableStickers = [
    '🔥 Hot', '❤️ Yêu', '😍 Mê', '🥳 Tiệc tùng', '🎉 Quẩy lên', '💯 Chuẩn 100',
    '✨ Lung linh', '🚀 Đi thôi', '🏖️ Đi biển', '☕ Cà phê', '🎧 Chill phết',
    '👑 Đỉnh cao', '🌸 Đáng yêu', '⚡ Năng lượng', '📍 Hà Nội', '📍 TP. Hồ Chí Minh',
    '📍 Đà Nẵng', '🕒 Bây giờ', '💬 Hỏi tôi đi'
  ];

  @override
  void initState() {
    super.initState();
    _selectedBgColor = _bgColors.first;
  }

  @override
  void dispose() {
    _textController.dispose();
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

  String _formatSeconds(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  TextStyle _getTextStyle(StoryTextStyle style, {double fontSize = 22}) {
    switch (style) {
      case StoryTextStyle.neat:
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
        );
      case StoryTextStyle.casual:
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          letterSpacing: 0,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 1))],
        );
      case StoryTextStyle.stylish:
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: Colors.white,
          letterSpacing: 1.2,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
        );
      case StoryTextStyle.headline:
        return TextStyle(
          fontSize: fontSize * 1.15,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3))],
        );
      case StoryTextStyle.pill:
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        );
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 1280,
        imageQuality: 60,
      );
      if (picked != null) {
        final rawBytes = await picked.readAsBytes();
        final optimizedBytes = await StorageService.safeOptimizeImageBytes(rawBytes);
        setState(() {
          _selectedImageBytes = optimizedBytes;
          _photoRotation = 0;
          _mode = StoryCreationMode.photo;
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

  void _rotatePhoto() {
    setState(() {
      _photoRotation = (_photoRotation + 90) % 360;
    });
  }

  void _onDiscard() {
    if (_mode != StoryCreationMode.select) {
      setState(() {
        _mode = StoryCreationMode.select;
        _selectedImageBytes = null;
        _textController.clear();
        _selectedMusic = null;
        _stickerItems.clear();
        _photoRotation = 0;
        _textOffset = Offset.zero;
      });
      AudioPlayerService.instance.stopTrack();
    } else {
      Navigator.pop(context);
    }
  }

  void _showStickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF242526),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Thêm Nhãn Dán / Sticker',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _availableStickers.map((st) {
                return ActionChip(
                  backgroundColor: Colors.white12,
                  label: Text(st, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    setState(() {
                      if (!_stickerItems.any((item) => item.text == st)) {
                        _stickerItems.add(StoryStickerItem(
                          text: st,
                          offset: Offset(0, -60.0 + _stickerItems.length * 35.0),
                        ));
                      }
                    });
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showMusicSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = MusicTrackLibrary.tracks.where((t) {
              return t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  t.artist.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: const Color(0xFF242526),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Thư viện 20 Bài Hát V-Pop Thật',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tìm bài hát, ca sĩ...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final track = filtered[i];
                        final isSelected = _selectedMusic?.id == track.id;

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              track.coverUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 48,
                                height: 48,
                                color: AppColors.primary,
                                child: const Icon(Icons.music_note_rounded, color: Colors.white),
                              ),
                            ),
                          ),
                          title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(track.artist, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 22)
                              : IconButton(
                                  icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.white70),
                                  onPressed: () {
                                    AudioPlayerService.instance.playTrack(track);
                                  },
                                ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showMusicSegmentSelector(track);
                          },
                        );
                      },
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

  void _showMusicSegmentSelector(MusicTrack track) {
    int tempStart = _musicStartSeconds;
    bool isPreviewPlaying = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF242526),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        track.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: AppColors.primary,
                          child: const Icon(Icons.music_note_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(track.artist, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            'Đoạn phát: ${_formatSeconds(tempStart)} - ${_formatSeconds(tempStart + 15)} (15s)',
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Kéo thanh trượt để chọn đoạn điệp khúc bạn thích:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Slider(
                  value: tempStart.toDouble(),
                  min: 0,
                  max: 180,
                  divisions: 36,
                  label: _formatSeconds(tempStart),
                  activeColor: AppColors.primaryLight,
                  inactiveColor: Colors.white24,
                  onChanged: (val) => setSheetState(() => tempStart = val.toInt()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('00:00 (Đầu)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('Bắt đầu: ${_formatSeconds(tempStart)}', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Text('03:00 (Cuối)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(isPreviewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(isPreviewPlaying ? 'Tạm dừng' : 'Nghe thử'),
                        onPressed: () async {
                          if (isPreviewPlaying) {
                            await AudioPlayerService.instance.pauseTrack();
                            setSheetState(() => isPreviewPlaying = false);
                          } else {
                            await AudioPlayerService.instance.playTrack(track, startSeconds: tempStart);
                            setSheetState(() => isPreviewPlaying = true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Chọn đoạn này', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          AudioPlayerService.instance.stopTrack();
                          setState(() {
                            _selectedMusic = track;
                            _musicStartSeconds = tempStart;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _publishStory() async {
    final caption = _textController.text.trim();

    if (_mode == StoryCreationMode.text && caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung cho tin văn bản!'),
          backgroundColor: AppColors.coralDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_mode == StoryCreationMode.photo && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ảnh trước khi chia sẻ!'),
          backgroundColor: AppColors.coralDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    setState(() => _isUploading = true);

    try {
      String? imageUrl;
      if (_selectedImageBytes != null) {
        imageUrl = await _storageService.uploadPostImageBytes(bytes: _selectedImageBytes!);
      }

      if (!mounted) return;
      final halfWidth = screenSize.width / 2;
      final halfHeight = screenSize.height / 2;
      final posX = (halfWidth > 0 ? _textOffset.dx / halfWidth : 0.0).clamp(-0.85, 0.85);
      final posY = (halfHeight > 0 ? _textOffset.dy / halfHeight : 0.0).clamp(-0.85, 0.85);

      final stickersList = _stickerItems.map((e) => e.text).toList();
      final stickerPositionsX = _stickerItems.map((e) => (halfWidth > 0 ? e.offset.dx / halfWidth : 0.0).clamp(-0.85, 0.85)).toList();
      final stickerPositionsY = _stickerItems.map((e) => (halfHeight > 0 ? e.offset.dy / halfHeight : 0.0).clamp(-0.85, 0.85)).toList();

      await _storyService.createStory(
        imageUrl: imageUrl,
        caption: caption,
        backgroundColor: _selectedBgColor,
        musicTrack: _selectedMusic,
        stickers: stickersList,
        stickerPositionsX: stickerPositionsX,
        stickerPositionsY: stickerPositionsY,
        textPositionX: posX,
        textPositionY: posY,
        musicStartTime: _musicStartSeconds,
        textStyle: _selectedStyle.name,
      );

      AudioPlayerService.instance.stopTrack();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chia sẻ lên Tin của bạn thành công!'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đăng tin: $e'), backgroundColor: AppColors.coralDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFF18191A),
      body: SafeArea(
        child: _mode == StoryCreationMode.select
            ? _buildLandingSelectionScreen(isDesktop)
            : _mode == StoryCreationMode.text
                ? _buildTextStoryScreen(isDesktop)
                : _buildPhotoStoryScreen(isDesktop),
      ),
    );
  }

  // ==========================================
  // BƯỚC 1: MÀN HÌNH CHỌN LOẠI TIN (LANDING)
  // ==========================================
  Widget _buildLandingSelectionScreen(bool isDesktop) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final userName = (user?.displayName != null && user!.displayName.isNotEmpty)
        ? user.displayName
        : (user?.email != null ? user!.email.split('@').first : 'Thành viên');
    final userAvatar = user?.photoUrl;

    return Column(
      children: [
        // Top App Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3B3C),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E65F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tin của bạn',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF3A3B3C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
              ),
            ],
          ),
        ),

        // User Profile info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              AvatarWidget(photoUrl: userAvatar, name: userName, radius: 22),
              const SizedBox(width: 12),
              Text(
                userName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),

        const Spacer(),

        // 2 Thẻ Chọn lớn phong cách Facebook Story
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Card 1: Tạo tin có ảnh hoặc video
                Expanded(
                  child: _buildActionCard(
                    title: 'Tạo tin có ảnh hoặc video',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E65F3), Color(0xFF5D9CEC), Color(0xFFA29BFE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.photo_library_rounded,
                    onTap: _pickImage,
                  ),
                ),
                const SizedBox(width: 14),

                // Card 2: Tạo tin dạng văn bản
                Expanded(
                  child: _buildActionCard(
                    title: 'Tạo tin dạng văn bản',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFAC5CD9), Color(0xFFED5565), Color(0xFFFAB1A0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    isAaIcon: true,
                    onTap: () {
                      setState(() {
                        _mode = StoryCreationMode.text;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required LinearGradient gradient,
    IconData? icon,
    bool isAaIcon = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF18191A),
                shape: BoxShape.circle,
              ),
              child: isAaIcon
                  ? const Center(
                      child: Text('Aa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    )
                  : Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BƯỚC 2A: TẠO TIN DẠNG VĂN BẢN (TEXT STORY)
  // ==========================================
  Widget _buildTextStoryScreen(bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          // Cột trái: Điều khiển
          SizedBox(
            width: 360,
            child: _buildTextControlsPanel(),
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          // Cột phải: Xem trước
          Expanded(
            child: Center(
              child: _buildStoryPreviewCard(isTextStory: true),
            ),
          ),
        ],
      );
    } else {
      // Mobile Layout: Preview ở trên, điều khiển ở dưới
      return Column(
        children: [
          _buildMobileAppBar('Tạo tin văn bản'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: _buildStoryPreviewCard(isTextStory: true),
              ),
            ),
          ),
          _buildTextMobileBottomBar(),
        ],
      );
    }
  }

  // ==========================================
  // BƯỚC 2B: TẠO TIN CÓ ẢNH (PHOTO STORY)
  // ==========================================
  Widget _buildPhotoStoryScreen(bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          SizedBox(
            width: 360,
            child: _buildPhotoControlsPanel(),
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(
            child: Center(
              child: _buildStoryPreviewCard(isTextStory: false),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildMobileAppBar('Tạo tin có ảnh'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: _buildStoryPreviewCard(isTextStory: false),
              ),
            ),
          ),
          _buildPhotoMobileBottomBar(),
        ],
      );
    }
  }

  // ----------------------------------------------------
  // PREVIEW CANVAS (VERTICAL 9:16 ASPECT RATIO CARD)
  // ----------------------------------------------------
  Widget _buildStoryPreviewCard({required bool isTextStory}) {
    final bgColor = _hexToColor(_selectedBgColor);
    final darkerBg = Color.lerp(bgColor, Colors.black, 0.3) ?? bgColor;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Nền
              if (isTextStory || _selectedImageBytes == null)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [bgColor, darkerBg],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
              else
                RotatedBox(
                  quarterTurns: _photoRotation ~/ 90,
                  child: Image.memory(
                    _selectedImageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),

              // Draggable Stickers (Kéo thả tự do trên story)
              ..._stickerItems.map((item) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final centerX = constraints.maxWidth / 2;
                    final centerY = constraints.maxHeight / 2;
                    final left = (centerX + item.offset.dx - 50).clamp(10.0, constraints.maxWidth - 120.0);
                    final top = (centerY + item.offset.dy - 18).clamp(60.0, constraints.maxHeight - 80.0);

                    return Positioned(
                      left: left,
                      top: top,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            item.offset += details.delta;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white38),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.text,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _stickerItems.remove(item);
                                  });
                                },
                                child: const Icon(Icons.close, size: 14, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),

              // Nhạc Pill
              if (_selectedMusic != null)
                Positioned(
                  top: 24,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, color: AppColors.accent, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_selectedMusic!.title} • ${_formatSeconds(_musicStartSeconds)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              AudioPlayerService.instance.stopTrack();
                              setState(() => _selectedMusic = null);
                            },
                            child: const Icon(Icons.close, size: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Nội dung Text
              if (isTextStory)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _selectedStyle == StoryTextStyle.pill
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _textController.text.isEmpty ? 'Bắt đầu nhập...' : _textController.text,
                              textAlign: TextAlign.center,
                              style: _getTextStyle(_selectedStyle),
                            ),
                          )
                        : Text(
                            _textController.text.isEmpty ? 'Bắt đầu nhập...' : _textController.text,
                            textAlign: TextAlign.center,
                            style: _getTextStyle(_selectedStyle),
                          ),
                  ),
                )
              else if (_textController.text.isNotEmpty)
                // Text kéo thả trên ảnh
                LayoutBuilder(
                  builder: (context, constraints) {
                    final centerX = constraints.maxWidth / 2;
                    final centerY = constraints.maxHeight / 2;
                    final boxW = (constraints.maxWidth * 0.85).clamp(180.0, 320.0);

                    return Stack(
                      children: [
                        Positioned(
                          left: (centerX + _textOffset.dx - (boxW / 2)).clamp(10.0, constraints.maxWidth - boxW - 10.0),
                          top: (centerY + _textOffset.dy - 30).clamp(60.0, constraints.maxHeight - 80.0),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _textOffset += details.delta;
                              });
                            },
                            child: Container(
                              width: boxW,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: _selectedStyle == StoryTextStyle.pill
                                  ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))
                                  : BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14)),
                              child: Text(
                                _textController.text,
                                textAlign: TextAlign.center,
                                style: _getTextStyle(_selectedStyle, fontSize: 18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // CỘT ĐIỀU KHIỂN DESKTOP CHO TEXT STORY
  // ----------------------------------------------------
  Widget _buildTextControlsPanel() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final userName = (user?.displayName != null && user!.displayName.isNotEmpty)
        ? user.displayName
        : (user?.email != null ? user!.email.split('@').first : 'Thành viên');
    final userAvatar = user?.photoUrl;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _onDiscard,
              ),
              const SizedBox(width: 8),
              const Text('Tin của bạn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AvatarWidget(photoUrl: userAvatar, name: userName, radius: 18),
              const SizedBox(width: 10),
              Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 18),

          // Ô nhập nội dung
          TextField(
            controller: _textController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Bắt đầu nhập...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF242526),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Dropdown chọn kiểu chữ chuẩn Facebook
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF242526),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StoryTextStyle>(
                value: _selectedStyle,
                dropdownColor: const Color(0xFF242526),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                items: StoryTextStyle.values.map((st) {
                  return DropdownMenuItem(
                    value: st,
                    child: Text('Aa ${st.label}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStyle = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Bảng chọn màu nền
          const Text('Phông nền', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _bgColors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final hex = _bgColors[i];
                final color = _hexToColor(hex);
                final isSelected = hex == _selectedBgColor;

                return GestureDetector(
                  onTap: () => setState(() => _selectedBgColor = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Nút Thêm nhạc
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.music_note_rounded, color: AppColors.accent),
            label: Text(_selectedMusic != null ? 'Đổi bài hát (${_selectedMusic!.title})' : 'Thêm nhạc'),
            onPressed: _showMusicSelector,
          ),
          const SizedBox(height: 10),

          // Nút Sticker
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.emoji_emotions_rounded, color: Colors.amber),
            label: const Text('Thêm Sticker'),
            onPressed: _showStickerSheet,
          ),

          const Spacer(),

          // 2 Nút: Bỏ & Chia sẻ lên tin
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3B3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _onDiscard,
                  child: const Text('Bỏ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E65F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isUploading ? null : _publishStory,
                  child: _isUploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Chia sẻ lên tin', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CỘT ĐIỀU KHIỂN DESKTOP CHO PHOTO STORY
  // ----------------------------------------------------
  Widget _buildPhotoControlsPanel() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final userName = (user?.displayName != null && user!.displayName.isNotEmpty)
        ? user.displayName
        : (user?.email != null ? user!.email.split('@').first : 'Thành viên');
    final userAvatar = user?.photoUrl;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _onDiscard,
              ),
              const SizedBox(width: 8),
              const Text('Tin của bạn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AvatarWidget(photoUrl: userAvatar, name: userName, radius: 18),
              const SizedBox(width: 10),
              Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 20),

          // Thêm văn bản lên ảnh
          TextField(
            controller: _textController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Thêm văn bản lên ảnh...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.text_fields_rounded, color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF242526),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Chọn kiểu chữ cho văn bản trên ảnh
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF242526),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StoryTextStyle>(
                value: _selectedStyle,
                dropdownColor: const Color(0xFF242526),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                items: StoryTextStyle.values.map((st) {
                  return DropdownMenuItem(
                    value: st,
                    child: Text('Aa ${st.label}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStyle = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nút Thêm nhạc
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.music_note_rounded, color: AppColors.accent),
            label: Text(_selectedMusic != null ? 'Đổi bài hát (${_selectedMusic!.title})' : 'Thêm nhạc'),
            onPressed: _showMusicSelector,
          ),
          const SizedBox(height: 10),

          // Nút Xoay ảnh
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.rotate_right_rounded, color: AppColors.primaryLight),
            label: Text('Xoay ảnh ($_photoRotation°)', style: const TextStyle(fontWeight: FontWeight.w600)),
            onPressed: _rotatePhoto,
          ),
          const SizedBox(height: 10),

          // Nút Đổi ảnh
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.photo_library_rounded, color: Colors.greenAccent),
            label: const Text('Đổi ảnh khác'),
            onPressed: _pickImage,
          ),
          const SizedBox(height: 10),

          // Nút Sticker
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.emoji_emotions_rounded, color: Colors.amber),
            label: const Text('Thêm Sticker'),
            onPressed: _showStickerSheet,
          ),

          const Spacer(),

          // 2 Nút: Bỏ & Chia sẻ
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3B3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _onDiscard,
                  child: const Text('Bỏ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E65F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isUploading ? null : _publishStory,
                  child: _isUploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Chia sẻ lên tin', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // GIAO DIỆN MOBILE APP BAR VÀ BOTTOM BAR
  // ----------------------------------------------------
  Widget _buildMobileAppBar(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _onDiscard,
          ),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.music_note_rounded, color: AppColors.accent),
            tooltip: 'Thêm nhạc',
            onPressed: _showMusicSelector,
          ),
          IconButton(
            icon: const Icon(Icons.emoji_emotions_rounded, color: Colors.amber),
            tooltip: 'Sticker',
            onPressed: _showStickerSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildTextMobileBottomBar() {
    return Container(
      color: const Color(0xFF242526),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ô nhập văn bản trực tiếp
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nhập nội dung chia sẻ...',
              hintStyle: const TextStyle(color: Colors.white38),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF3A3B3C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Chọn kiểu chữ & Bảng màu
          Row(
            children: [
              // Chọn kiểu chữ (Dropdown nhỏ)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3B3C),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<StoryTextStyle>(
                    value: _selectedStyle,
                    dropdownColor: const Color(0xFF242526),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                    items: StoryTextStyle.values.map((st) {
                      return DropdownMenuItem(
                        value: st,
                        child: Text(st.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStyle = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Màu nền
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _bgColors.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final hex = _bgColors[i];
                      final color = _hexToColor(hex);
                      final isSelected = hex == _selectedBgColor;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedBgColor = hex),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nút Bỏ & Chia sẻ
          Row(
            children: [
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3B3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _onDiscard,
                  child: const Text('Bỏ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    onPressed: _isUploading ? null : _publishStory,
                    child: _isUploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Chia sẻ lên tin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoMobileBottomBar() {
    return Container(
      color: const Color(0xFF242526),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Thêm text lên ảnh
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Thêm chữ lên ảnh...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF3A3B3C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Nút Xoay
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF3A3B3C)),
                  icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                  tooltip: 'Xoay ảnh',
                  onPressed: _rotatePhoto,
                ),
                // Nút Đổi ảnh
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF3A3B3C)),
                  icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                  tooltip: 'Đổi ảnh khác',
                  onPressed: _pickImage,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nút Bỏ & Chia sẻ
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3B3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onDiscard,
                    child: const Text('Bỏ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: _isUploading ? null : _publishStory,
                      child: _isUploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Chia sẻ lên tin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
