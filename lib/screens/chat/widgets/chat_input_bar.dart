import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/clipboard_image_helper.dart';
import '../../../utils/geolocation_helper.dart';
import '../../../utils/voice_recorder_helper.dart';
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
  late final FocusNode _focusNode;
  final ImagePicker _picker = ImagePicker();
  bool _showEmojiPanel = false;
  Timer? _typingTimer;
  bool _isTyping = false;

  // Ảnh đính kèm chờ gửi (khi Paste hoặc Chọn ảnh từ thư viện)
  Uint8List? _pendingImageBytes;

  // Trạng thái ghi âm Voice
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Quản lý danh mục Emoji
  int _selectedEmojiCategory = 0;

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
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          if (!HardwareKeyboard.instance.isShiftPressed) {
            _handleSend();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
    _textController.addListener(_handleTextChange);
    // Khi dán ảnh từ clipboard (Ctrl+V): chỉ đính kèm ảnh vào ô soạn thảo chờ người dùng nhấn Enter / nút Gửi
    ClipboardImageHelper.listenForPastedImages((bytes) {
      if (mounted) {
        setState(() {
          _pendingImageBytes = bytes;
        });
        _focusNode.requestFocus();
      }
    });
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
    final imageBytes = _pendingImageBytes;

    if (imageBytes == null && text.isEmpty) return;

    // 1. Gửi ảnh đính kèm nếu có
    if (imageBytes != null) {
      if (widget.onSendImageBytes != null) {
        widget.onSendImageBytes!(imageBytes);
      }
      setState(() {
        _pendingImageBytes = null;
      });
    }

    // 2. Gửi văn bản tin nhắn nếu có
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _textController.clear();
      _typingTimer?.cancel();
      _isTyping = false;
      widget.onTypingStop?.call();
    }
  }

  // --- Voice Message Handler (Thu âm & Phát 100% Giọng nói thật từ Microphone) ---
  Future<void> _startRecording() async {
    final ok = await VoiceRecorderHelper.startRecording();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng cho phép quyền Micro trên trình duyệt để thu âm giọng nói thật!'),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
    VoiceRecorderHelper.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  Future<void> _sendRecording() async {
    _recordTimer?.cancel();
    final mins = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordSeconds % 60).toString().padLeft(2, '0');
    final durationStr = '$mins:$secs';

    final audioUrl = await VoiceRecorderHelper.stopRecording();

    if (audioUrl != null && audioUrl.isNotEmpty) {
      widget.onSendVoice?.call(audioUrl, durationStr);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thu được âm thanh. Hãy thử nói to hơn nhé!'),
            backgroundColor: AppColors.coralDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

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
        if (mounted) {
          setState(() {
            _pendingImageBytes = bytes;
          });
          _focusNode.requestFocus();
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
                      label: 'Emoji',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
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
                        _handleLocationOption();
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

  Future<void> _handleLocationOption() async {
    final bool? shouldShareReal = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.my_location_rounded, color: AppColors.coralDanger, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chia sẻ vị trí thực tế',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SupaChat muốn truy cập vị trí thực tế của bạn qua GPS để gửi toạ độ và địa chỉ chính xác vào đoạn chat.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Bạn có đồng ý cho phép định vị và chia sẻ vị trí thật không?',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx, null);
            },
            child: const Text('Chọn địa điểm mẫu', style: TextStyle(color: AppColors.electricBlue)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Cho phép & Chia sẻ', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(dialogCtx, true),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldShareReal == true) {
      await _locateAndSendRealPosition();
    } else if (shouldShareReal == null) {
      _showLocationDialog();
    }
  }

  Future<void> _locateAndSendRealPosition() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Row(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đang định vị GPS...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Vui lòng chọn Cho phép nếu trình duyệt hiển thị thông báo quyền vị trí.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await GeolocationHelper.getCurrentLocation();
      if (!mounted) return;

      if (widget.onSendLocation != null) {
        await widget.onSendLocation!(
          result.locationName,
          result.address,
          result.latitude,
          result.longitude,
        );
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 Đã chia sẻ vị trí thực tế: ${result.locationName}'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final errorMsg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lấy vị trí: $errorMsg'),
          backgroundColor: AppColors.coralDanger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _handleLocationOption();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.my_location_rounded, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Chia sẻ vị trí GPS thực tế',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Xác định toạ độ chính xác từ thiết bị của bạn',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hoặc chọn địa điểm mẫu:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 6),
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
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (widget.onSendLocation != null) {
                        await widget.onSendLocation!(
                          p['name'] as String,
                          p['address'] as String,
                          p['lat'] as double,
                          p['lng'] as double,
                        );
                      }
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
    ClipboardImageHelper.dispose();
    _focusNode.dispose();
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
    final hasContent = hasText || _pendingImageBytes != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEmojiPanel) _buildEmojiPanel(isDark, textPrimary, textSecondary),

        // Khung xem trước hình ảnh đính kèm chờ gửi (khi dán hoặc chọn ảnh)
        if (_pendingImageBytes != null)
          Container(
            color: barBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _pendingImageBytes!,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _pendingImageBytes = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.image_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Đã đính kèm ảnh',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Nhấn Enter hoặc nút Gửi để gửi ảnh đi',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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
                                  focusNode: _focusNode,
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

                      // Nút Gửi (hoặc Mic ghi âm Voice Note nếu chưa có text và ảnh)
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
                                gradient: hasContent ? AppColors.brandGradient : null,
                                color: hasContent ? null : actionBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  hasContent ? Icons.send_rounded : Icons.mic_rounded,
                                  size: 20,
                                  color: hasContent
                                      ? Colors.white
                                      : (isDark ? AppColors.primaryLight : AppColors.primary),
                                ),
                                tooltip: hasContent ? 'Gửi tin nhắn' : 'Ghi âm tin nhắn thoại (Voice)',
                                onPressed: hasContent ? _handleSend : _startRecording,
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

  // --- Widget Panel Emoji thuần túy (Theo danh mục) ---
  Widget _buildEmojiPanel(bool isDark, Color textPrimary, Color textSecondary) {
    final panelBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      height: 270,
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(top: BorderSide(color: borderCol)),
      ),
      child: _buildEmojiCategoryView(textPrimary, textSecondary),
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

}
