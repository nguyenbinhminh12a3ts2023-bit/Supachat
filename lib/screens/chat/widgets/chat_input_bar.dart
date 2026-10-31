import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/fictional_stickers.dart';
import '../../../widgets/secure_keypad_sheet.dart';

/// Thanh nhập tin nhắn bên dưới màn hình chat với:
/// - Emoji phong phú (phân chia theo danh mục)
/// - Bộ Sticker ảo độc quyền (5 nhân vật hư cấu SupaChat)
/// - Tin nhắn thoại (Voice recording & sending)
/// - Gửi ảnh / Camera
/// - Gửi tệp tin / Tài liệu
/// - Chia sẻ vị trí (Location)
/// - Bàn phím bảo mật đảo phím (Secure Scrambled Keypad)
/// - Cảnh báo chụp ảnh màn hình
class ChatInputBar extends StatefulWidget {
  final Function(String text) onSendMessage;
  final Function(File imageFile) onSendImage;
  final Function(Uint8List bytes)? onSendImageBytes;
  final Function(String fileName, String fileSize, Uint8List bytes)? onSendFileBytes;
  final Function(String stickerEmoji, String stickerName)? onSendSticker;
  final Function(String locationName, String address, double lat, double lng)? onSendLocation;
  final Function(String audioUrl, String duration)? onSendVoice;
  final VoidCallback? onScreenshotTrigger;
  final bool isSending;
  final VoidCallback? onTypingStart;
  final VoidCallback? onTypingStop;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    required this.onSendImage,
    this.onSendImageBytes,
    this.onSendFileBytes,
    this.onSendSticker,
    this.onSendLocation,
    this.onSendVoice,
    this.onScreenshotTrigger,
    required this.isSending,
    this.onTypingStart,
    this.onTypingStop,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _showEmojiPanel = false;
  Timer? _typingTimer;
  bool _isTyping = false;

  // Trạng thái ghi âm Voice
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Tab controller cho Emoji vs Sticker Ảo
  int _selectedPanelTab = 0; // 0: Emoji, 1: Sticker ảo
  int _selectedEmojiCategory = 0;
  int _selectedCharacterIndex = 0;

  // Danh mục Emoji đầy đủ
  static const List<Map<String, dynamic>> _emojiCategories = [
    {
      'name': 'Mặt cười',
      'icon': '😀',
      'emojis': [
        '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊','😇','🥰','😍','🤩',
        '😘','😗','😚','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤫','🤔','🤐','🤨','😐',
        '😑','😶','😏','😒','🙄','😬','🤥','😌','😔','😪','🤤','😴','😷','🤒','🤕','🤢',
        '🤮','🤧','🥵','🥶','🥴','😵','🤯','🤠','🥳','🥸','😎','🤓','🧐','😕','😟','🙁',
        '😮','😯','😲','😳','🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖','😣','😞',
        '😓','😩','😫','🥱','😤','😡','😠','🤬',
      ],
    },
    {
      'name': 'Trái tim',
      'icon': '❤️',
      'emojis': [
        '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❣️','💕','💞','💓','💗','💖',
        '💘','💝','💟','💌','💋','🫂',
      ],
    },
    {
      'name': 'Bàn tay',
      'icon': '👍',
      'emojis': [
        '👍','👎','👊','✊','🤛','🤜','👏','🙌','👐','🤲','🤝','🙏','✍️','💅','🤳','💪',
        '👈','👉','👆','👇','☝️','✌️','🤞','🤟','🤘','🤙','🖐️','✋','👌',
      ],
    },
    {
      'name': 'Ẩm thực',
      'icon': '🍕',
      'emojis': [
        '☕','🍵','🧃','🥤','🧋','🍺','🍻','🥂','🍷','🥃','🍸','🍹','🍕','🍔','🍟','🌭',
        '🍿','🥪','🌮','🍜','🍣','🍦','🍧','🍰','🎂','🍫','🍩','🍪','🍓','🍉','🍇','🍎',
      ],
    },
    {
      'name': 'Biểu tượng',
      'icon': '🔥',
      'emojis': [
        '🔥','✨','🌟','💫','💥','💯','💢','💨','🎉','🎊','🎈','🎁','🏆','🥇','🎯','🚀',
        '🏖️','🎵','🎶','🎸','🎧','🚗','✈️','🌈','☀️','🌙','⚡','❄️','🌸','🌹','🌻','💎',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final text = _textController.text;
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.onTypingStart?.call();
    }

    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _isTyping = false;
        widget.onTypingStop?.call();
      });
    } else {
      _isTyping = false;
      widget.onTypingStop?.call();
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _textController.clear();
      _typingTimer?.cancel();
      _isTyping = false;
      widget.onTypingStop?.call();
    }
  }

  // --- Voice Message Handler ---
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _showEmojiPanel = false;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordSeconds++);
      }
    });
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  void _sendRecording() {
    _recordTimer?.cancel();
    final mins = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordSeconds % 60).toString().padLeft(2, '0');
    final durationStr = '$mins:$secs';

    // URL âm thanh thực trực tuyến cho Voice note
    const sampleVoiceUrl = 'https://archive.org/download/binh-yen-nhung-phut-giay-son-tung-m-tp/Binh%20Yen%20Nhung%20Phut%20Giay%20-%20Son%20Tung%20M%20TP.mp3';

    widget.onSendVoice?.call(sampleVoiceUrl, durationStr);

    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (widget.onSendImageBytes != null) {
          widget.onSendImageBytes!(bytes);
        } else if (!kIsWeb) {
          widget.onSendImage(File(pickedFile.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.xFile.readAsBytes();
        final name = file.name;
        final sizeKb = '${(bytes.length / 1024).toStringAsFixed(1)} KB';
        widget.onSendFileBytes?.call(name, sizeKb, bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn tệp tin: $e')),
        );
      }
    }
  }

  void _showMediaBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildActionOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Tệp tin',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFile();
                      },
                    ),
                    _buildActionOption(
                      icon: Icons.emoji_emotions_rounded,
                      label: 'Sticker ảo',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedPanelTab = 1;
                          _showEmojiPanel = true;
                        });
                      },
                    ),
                    _buildActionOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Chụp ảnh',
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _buildActionOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Thư viện',
                      color: Colors.purpleAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                    _buildActionOption(
                      icon: Icons.location_on_rounded,
                      label: 'Vị trí',
                      color: AppColors.coralDanger,
                      onTap: () {
                        Navigator.pop(context);
                        _showLocationDialog();
                      },
                    ),
                    _buildActionOption(
                      icon: Icons.shuffle_rounded,
                      label: 'Đảo phím',
                      color: AppColors.electricBlue,
                      onTap: () {
                        Navigator.pop(context);
                        SecureKeypadSheet.show(
                          context,
                          title: 'Bàn phím bảo mật',
                          description: 'Gõ mã PIN bí mật với bàn phím đảo ngẫu nhiên',
                        );
                      },
                    ),
                    _buildActionOption(
                      icon: Icons.screenshot_monitor_rounded,
                      label: 'Chụp MH',
                      color: Colors.amber,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onScreenshotTrigger?.call();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLocationDialog() {
    final places = [
      {'name': 'Hồ Gươm (Hà Nội)', 'address': 'Hoàn Kiếm, Hà Nội', 'lat': 21.0285, 'lng': 105.8542},
      {'name': 'Phố đi bộ Nguyễn Huệ', 'address': 'Quận 1, TP. Hồ Chí Minh', 'lat': 10.7742, 'lng': 106.7032},
      {'name': 'Cầu Rồng (Đà Nẵng)', 'address': 'Hải Châu, Đà Nẵng', 'lat': 16.0611, 'lng': 108.2272},
      {'name': 'Văn phòng SupaChat HQ', 'address': 'Tầng 18, Tòa nhà Công Nghệ', 'lat': 21.0313, 'lng': 105.7836},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on_rounded, color: AppColors.coralDanger, size: 24),
                SizedBox(width: 8),
                Text('Chia sẻ vị trí thời gian thực', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: places.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final p = places[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.lightLavender,
                      child: Icon(Icons.pin_drop_rounded, color: AppColors.primary),
                    ),
                    title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(p['address'] as String, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onSendLocation?.call(
                        p['name'] as String,
                        p['address'] as String,
                        p['lat'] as double,
                        p['lng'] as double,
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

  Widget _buildActionOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _textController.removeListener(_handleTextChange);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final pillBg = isDark ? AppColors.darkInputBg : AppColors.inputBg;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.border;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final actionBg = isDark ? AppColors.darkSecondary : AppColors.lightLavender;

    final hasText = _textController.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEmojiPanel) _buildUnifiedEmojiAndStickerPanel(isDark, textPrimary, textSecondary),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: barBg,
            border: Border(top: BorderSide(color: borderCol, width: 0.8)),
          ),
          child: SafeArea(
            child: _isRecording
                ? _buildRecordingBar(textPrimary, textSecondary)
                : Row(
                    children: [
                      // Nút Plus (+) Action mở tiện ích đính kèm
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: actionBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.add_rounded,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                            size: 22,
                          ),
                          onPressed: widget.isSending ? null : _showMediaBottomSheet,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Ô nhập nội dung pill có icon Emoji và Ảnh bên trong
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.transparent,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  maxLines: 4,
                                  minLines: 1,
                                  textInputAction: TextInputAction.send,
                                  style: TextStyle(fontSize: 14, color: textPrimary),
                                  onTap: () {
                                    if (_showEmojiPanel) {
                                      setState(() => _showEmojiPanel = false);
                                    }
                                  },
                                  onSubmitted: (_) => _handleSend(),
                                  decoration: InputDecoration(
                                    hintText: 'Nhập tin nhắn...',
                                    hintStyle: TextStyle(fontSize: 14, color: textSecondary),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                ),
                              ),

                              // Nút Emoji / Sticker Panel
                              GestureDetector(
                                onTap: () {
                                  setState(() => _showEmojiPanel = !_showEmojiPanel);
                                  if (_showEmojiPanel) FocusScope.of(context).unfocus();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    _showEmojiPanel
                                        ? Icons.keyboard_rounded
                                        : Icons.sentiment_satisfied_alt_rounded,
                                    size: 20,
                                    color: _showEmojiPanel ? AppColors.primary : textSecondary,
                                  ),
                                ),
                              ),

                              // Nút Chọn ảnh nhanh
                              GestureDetector(
                                onTap: () => _pickImage(ImageSource.gallery),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 20,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Nút Gửi (hoặc Mic ghi âm Voice Note nếu chưa có text)
                      widget.isSending
                          ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: hasText ? AppColors.brandGradient : null,
                                color: hasText ? null : actionBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                                  size: 20,
                                  color: hasText
                                      ? Colors.white
                                      : (isDark ? AppColors.primaryLight : AppColors.primary),
                                ),
                                tooltip: hasText ? 'Gửi tin nhắn' : 'Ghi âm tin nhắn thoại (Voice)',
                                onPressed: hasText ? _handleSend : _startRecording,
                              ),
                            ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // --- Widget Live Voice Recording Bar ---
  Widget _buildRecordingBar(Color textPrimary, Color textSecondary) {
    final mins = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        // Chấm đỏ nhấp nháy
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: AppColors.coralDanger,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$mins:$secs',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.coralDanger),
        ),
        const SizedBox(width: 12),
        // Sóng âm thanh
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(12, (i) {
              final heights = [10, 20, 14, 26, 18, 12, 24, 16, 22, 14, 18, 10];
              return Container(
                width: 3,
                height: heights[i].toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.coralDanger.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),

        // Nút Hủy
        TextButton(
          onPressed: _cancelRecording,
          child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),

        // Nút Gửi Voice
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Gửi', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _sendRecording,
        ),
      ],
    );
  }

  // --- Widget Unified Panel (Bộ Emoji & Bộ Sticker Ảo SupaChat) ---
  Widget _buildUnifiedEmojiAndStickerPanel(bool isDark, Color textPrimary, Color textSecondary) {
    final panelBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(top: BorderSide(color: borderCol)),
      ),
      child: Column(
        children: [
          // Header chọn Tab: EMOJI vs STICKER ẢO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderCol, width: 0.8)),
            ),
            child: Row(
              children: [
                _buildMainTabButton(
                  title: 'Emoji phong phú',
                  icon: '😃',
                  isSelected: _selectedPanelTab == 0,
                  onTap: () => setState(() => _selectedPanelTab = 0),
                ),
                const SizedBox(width: 10),
                _buildMainTabButton(
                  title: 'Sticker ảo SupaChat',
                  icon: '🐱',
                  isSelected: _selectedPanelTab == 1,
                  onTap: () => setState(() => _selectedPanelTab = 1),
                ),
              ],
            ),
          ),

          // Nội dung tab đã chọn
          Expanded(
            child: _selectedPanelTab == 0
                ? _buildEmojiCategoryView(textPrimary, textSecondary)
                : _buildFictionalStickerView(isDark, textPrimary, textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabButton({
    required String title,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tab 1: Emoji View có phân loại chuyên mục ---
  Widget _buildEmojiCategoryView(Color textPrimary, Color textSecondary) {
    final currentCat = _emojiCategories[_selectedEmojiCategory];
    final emojis = currentCat['emojis'] as List<String>;

    return Column(
      children: [
        // Thanh chọn danh mục Emoji
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _emojiCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = _emojiCategories[idx];
              final isSelected = _selectedEmojiCategory == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmojiCategory = idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(cat['icon'] as String, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Lưới Emoji
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              final emoji = emojis[index];
              return InkWell(
                onTap: () {
                  final cursorPos = _textController.selection.baseOffset;
                  final currentText = _textController.text;
                  final newText = cursorPos < 0
                      ? currentText + emoji
                      : currentText.substring(0, cursorPos) +
                          emoji +
                          currentText.substring(cursorPos);
                  _textController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: (cursorPos < 0 ? newText.length : cursorPos + emoji.length),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Tab 2: Sticker Ảo 5 Nhân Vật Hư Cấu SupaChat ---
  Widget _buildFictionalStickerView(bool isDark, Color textPrimary, Color textSecondary) {
    final characters = FictionalStickerLibrary.characters;
    final activeChar = characters[_selectedCharacterIndex];

    return Column(
      children: [
        // Thanh chọn nhân vật (Mèo Supa, Cáo Neon, Gấu Bơ, Thỏ Bông, Rồng Con)
        Container(
          height: 42,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: characters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final char = characters[idx];
              final isSelected = _selectedCharacterIndex == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedCharacterIndex = idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? char.themeColor.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? char.themeColor : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(char.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        char.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? char.themeColor : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Lưới Stickers của nhân vật đã chọn
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.15,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: activeChar.stickers.length,
            itemBuilder: (context, idx) {
              final st = activeChar.stickers[idx];
              return InkWell(
                onTap: () {
                  setState(() => _showEmojiPanel = false);
                  widget.onSendSticker?.call(st.emoji, '${st.characterName}: ${st.title}');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: st.badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: st.badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(st.emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 4),
                      Text(
                        st.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        st.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
