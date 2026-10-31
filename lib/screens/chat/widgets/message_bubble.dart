import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../models/message_model.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/translation_service.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/url_helper.dart';
import '../../../utils/voice_recorder_helper.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/post_detail_modal.dart';

/// Bong bóng hiển thị tin nhắn (văn bản, hình ảnh, vị trí, tệp tin, sticker, dịch thuật)
class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onDelete;
  final VoidCallback? onUnsend;
  final String? senderAvatar;
  final String? senderName;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onDelete,
    this.onUnsend,
    this.senderAvatar,
    this.senderName,
    this.showAvatar = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String? _translatedText;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    AudioPlayerService.instance.addListener(_onAudioStateChange);
  }

  @override
  void dispose() {
    AudioPlayerService.instance.removeListener(_onAudioStateChange);
    super.dispose();
  }

  void _onAudioStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _translateMessage() async {
    if (_translatedText != null) {
      setState(() => _translatedText = null);
      return;
    }

    setState(() => _isTranslating = true);
    final isVietnamese = RegExp(r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]', caseSensitive: false).hasMatch(widget.message.text);
    final targetLang = isVietnamese ? 'en' : 'vi';

    final result = await TranslationService().translateText(
      widget.message.text,
      targetLang: targetLang,
    );
    if (mounted) {
      setState(() {
        _translatedText = result;
        _isTranslating = false;
      });
    }
  }

  void _showMessageOptions(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final isMe = widget.isMe;
    final message = widget.message;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        isMe ? offset.dx : offset.dx + size.width,
        offset.dy,
        isMe ? offset.dx + size.width : offset.dx,
        offset.dy + size.height,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
      items: [
        if (message.type == MessageType.text || message.type == MessageType.location)
          PopupMenuItem(
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép nội dung tin nhắn'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.copy_rounded, size: 20, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Text('Sao chép', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
        if (message.type == MessageType.image && message.mediaUrl != null)
          PopupMenuItem(
            onTap: () async {
              await DownloadHelper.downloadImage(message.mediaUrl!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đang tải hình ảnh về thiết bị...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Row(
              children: [
                Icon(Icons.download_rounded, size: 20, color: AppColors.tealAccent),
                SizedBox(width: 10),
                Text('Tải ảnh về máy', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
        if (message.type == MessageType.text)
          PopupMenuItem(
            onTap: _translateMessage,
            child: Row(
              children: [
                const Icon(Icons.g_translate_rounded, size: 20, color: AppColors.tealAccent),
                const SizedBox(width: 10),
                Text(
                  _translatedText != null ? 'Ẩn bản dịch' : 'Dịch tin nhắn',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        if (isMe)
          PopupMenuItem(
            onTap: widget.onUnsend,
            child: const Row(
              children: [
                Icon(Icons.undo_rounded, size: 20, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Thu hồi tin nhắn', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
        PopupMenuItem(
          onTap: widget.onDelete,
          child: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
              SizedBox(width: 10),
              Text('Xóa', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    final timeStr = DateFormat('HH:mm').format(message.timestamp);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. CẢNH BÁO CHỤP MÀN HÌNH
    if (message.type == MessageType.screenshotAlert) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.text,
                  style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. THÔNG BÁO BÀN PHÍM BẢO MẬT & CUỘC GỌI
    if (message.type == MessageType.secureKeypadNotice) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.type == MessageType.callNotice) {
      final isMissed = message.text.contains('nhỡ') ||
          message.text.contains('Từ chối') ||
          message.text.contains('kết thúc');
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isMissed
                ? AppColors.coralDanger.withValues(alpha: 0.12)
                : AppColors.tealAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isMissed
                  ? AppColors.coralDanger.withValues(alpha: 0.35)
                  : AppColors.tealAccent.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMissed ? Icons.phone_missed_rounded : Icons.phone_in_talk_rounded,
                size: 16,
                color: isMissed ? AppColors.coralDanger : AppColors.tealAccent,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${message.text} • $timeStr',
                  style: TextStyle(
                    color: isMissed ? AppColors.coralDanger : AppColors.tealAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. STICKER ĐỘC QUYỀN
    if (message.type == MessageType.sticker) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                if (widget.showAvatar)
                  AvatarWidget(
                    photoUrl: widget.senderAvatar,
                    name: widget.senderName ?? 'Bạn',
                    radius: 14,
                  )
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(fontSize: 48),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 4. BONG BÓNG TIN NHẮN CHÍNH
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar của đối phương bên trái cố định 28px (không giật khi dịch)
            if (!isMe) ...[
              if (widget.showAvatar)
                AvatarWidget(
                  photoUrl: widget.senderAvatar,
                  name: widget.senderName ?? 'Bạn',
                  radius: 14,
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],

            // Khung bong bóng tin nhắn
            Flexible(
              child: GestureDetector(
                onLongPress: () => _showMessageOptions(context),
                child: Container(
                  padding: message.type == MessageType.image
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: isMe ? AppColors.brandGradient : null,
                    color: isMe
                        ? null
                        : (isDark ? AppColors.darkInputBg : AppColors.lightLavender),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(6),
                      bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(20),
                    ),
                    border: isMe
                        ? null
                        : Border.all(
                            color: isDark ? AppColors.darkBorder : const Color(0xFFDCD8FB),
                            width: 0.8,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Nội dung
                      if (message.type == MessageType.image && message.mediaUrl != null)
                        _buildImageContent(context)
                      else if (message.type == MessageType.voice)
                        _buildVoiceContent(context, isDark)
                      else if (message.type == MessageType.location)
                        _buildLocationContent(context)
                      else if (message.type == MessageType.file)
                        _buildFileContent(context, isDark)
                      else if (message.postId != null || message.content.contains('[Bài viết'))
                        _buildSharedPostCard(context, isDark, isMe)
                      else ...[
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : (isDark ? AppColors.darkReceiverText : AppColors.receiverText),
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                        // Bản dịch thuật ngữ nếu có
                        if (_translatedText != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.translate_rounded, size: 13, color: AppColors.tealAccent),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _translatedText!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: isMe ? Colors.white.withValues(alpha: 0.9) : AppColors.tealAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 4),

                      // Thời gian & Icon đã xem
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              fontSize: 11,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isSeen ? Icons.done_all_rounded : Icons.done_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Nút dịch nhanh bên phải bong bóng đối phương -> không làm giật avatar bên trái
            if (!isMe && message.type == MessageType.text) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: _isTranslating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : Icon(
                        Icons.g_translate_rounded,
                        size: 18,
                        color: _translatedText != null ? AppColors.tealAccent : AppColors.textSecondary,
                      ),
                tooltip: 'Dịch tin nhắn',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _translateMessage,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileContent(BuildContext context, bool isDark) {
    final fileName = widget.message.fileName ?? widget.message.text;
    final fileSize = widget.message.fileSize ?? 'Tệp đính kèm';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: widget.isMe ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primaryLight, size: 26),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  fileSize,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.download_rounded, size: 18, color: AppColors.tealAccent),
        ],
      ),
    );
  }

  Widget _buildLocationContent(BuildContext context) {
    final lat = widget.message.latitude;
    final lng = widget.message.longitude;
    final hasCoords = lat != null && lng != null && (lat != 0.0 || lng != 0.0);
    final mapUrl = hasCoords ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : null;

    return InkWell(
      onTap: mapUrl != null ? () => UrlHelper.openUrl(mapUrl) : null,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 95,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.coralDanger, size: 30),
                      const SizedBox(height: 4),
                      Text(
                        hasCoords ? '📍 ${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°' : 'Bản đồ vị trí',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (hasCoords)
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, color: Colors.white, size: 10),
                          SizedBox(width: 3),
                          Text('Maps', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message.text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: widget.isMe
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1E293B)),
            ),
          ),
          if (widget.message.locationAddress != null &&
              widget.message.locationAddress!.isNotEmpty &&
              widget.message.locationAddress != widget.message.text) ...[
            const SizedBox(height: 4),
            Text(
              widget.message.locationAddress!,
              style: TextStyle(
                fontSize: 12,
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.85)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : const Color(0xFF475569)),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static final Map<String, Uint8List> _base64Cache = {};

  static Uint8List? _getDecodedBytes(String url) {
    if (_base64Cache.containsKey(url)) {
      return _base64Cache[url];
    }
    try {
      final base64Str = url.contains(',') ? url.split(',').last : url;
      final bytes = base64Decode(base64Str);
      if (_base64Cache.length > 60) {
        _base64Cache.remove(_base64Cache.keys.first);
      }
      _base64Cache[url] = bytes;
      return bytes;
    } catch (e) {
      return null;
    }
  }

  Widget _buildBrokenImagePlaceholder() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, size: 36, color: AppColors.textSecondary),
            SizedBox(height: 6),
            Text(
              'Không thể hiển thị ảnh',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final mediaUrl = widget.message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return _buildBrokenImagePlaceholder();
    }

    final isBase64 = mediaUrl.startsWith('data:image');
    final bytes = isBase64 ? _getDecodedBytes(mediaUrl) : null;

    Widget imageWidget;
    if (isBase64) {
      if (bytes != null) {
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildBrokenImagePlaceholder(),
        );
      } else {
        imageWidget = _buildBrokenImagePlaceholder();
      }
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        memCacheWidth: 800,
        maxWidthDiskCache: 1200,
        placeholder: (context, url) => Container(
          height: 180,
          color: AppColors.surface,
          child: const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildBrokenImagePlaceholder(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => _openImagePreview(context),
        child: Hero(
          tag: 'image_${widget.message.id}',
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildVoiceContent(BuildContext context, bool isDark) {
    final audioUrl = widget.message.mediaUrl ?? '';
    final messageId = widget.message.id.isNotEmpty
        ? widget.message.id
        : '${widget.message.timestamp.millisecondsSinceEpoch}_${widget.message.senderId}';
    final isPlaying = VoiceRecorderHelper.isMessagePlaying(messageId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (audioUrl.isNotEmpty) {
                AudioPlayerService.instance.stopTrack();
                VoiceRecorderHelper.playAudio(
                  messageId: messageId,
                  audioUrl: audioUrl,
                  onEnded: () {
                    if (mounted) setState(() {});
                  },
                  onPlayStateChanged: () {
                    if (mounted) setState(() {});
                  },
                  onSampleOldMessage: () {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đây là tin nhắn mẫu cũ từ phiên bản trước. Hãy bấm giữ Micro bên dưới để gửi tin nhắn thoại với giọng nói thật 100%!'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white24 : AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? Colors.white : AppColors.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(14, (i) {
                  final heights = [10, 18, 8, 22, 14, 26, 16, 20, 10, 24, 18, 14, 20, 12];
                  final isHighlight = isPlaying && (i % 2 == 0);
                  return Container(
                    width: 3,
                    height: heights[i % heights.length].toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? (isHighlight ? Colors.white : Colors.white70)
                          : (isHighlight ? AppColors.tealAccent : AppColors.primary),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    Icons.mic_rounded,
                    size: 11,
                    color: widget.isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    widget.message.text.isNotEmpty ? widget.message.text : '00:05',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openImagePreview(BuildContext context) {
    final mediaUrl = widget.message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    final isBase64 = mediaUrl.startsWith('data:image');
    final bytes = isBase64 ? _getDecodedBytes(mediaUrl) : null;

    Widget previewWidget;
    if (isBase64) {
      if (bytes != null) {
        previewWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.white60, size: 64),
          ),
        );
      } else {
        previewWidget = const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white60, size: 64),
        );
      }
    } else {
      previewWidget = CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white60, size: 64),
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.senderName ?? 'Hình ảnh',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                tooltip: 'Tải ảnh về máy',
                onPressed: () async {
                  await DownloadHelper.downloadImage(mediaUrl);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đang tải hình ảnh về thiết bị...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'image_${widget.message.id}',
                child: previewWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedPostCard(BuildContext context, bool isDark, bool isMe) {
    final msg = widget.message;
    String authorName = 'Bài viết';
    String postContent = msg.content;

    if (msg.content.contains('[Bài viết từ ') && msg.content.contains(']: ')) {
      final start = msg.content.indexOf('[Bài viết từ ') + '[Bài viết từ '.length;
      final end = msg.content.indexOf(']: ');
      if (end > start) {
        authorName = msg.content.substring(start, end).trim();
        postContent = msg.content.substring(end + ']: '.length).trim();
      }
    } else if (msg.content.contains('🔗 [Bài viết]: ')) {
      postContent = msg.content.replaceFirst('🔗 [Bài viết]: ', '').trim();
    }

    final hasImage = msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        PostDetailModal.show(
          context,
          postId: msg.postId,
          fallbackAuthor: authorName,
          fallbackContent: postContent,
          fallbackImage: msg.mediaUrl,
        );
      },
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E2130) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? Colors.white.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: huy hiệu bài viết + tên tác giả
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.black.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.article_rounded,
                    size: 15,
                    color: isMe ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bài viết từ $authorName',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: isMe ? Colors.white.withValues(alpha: 0.8) : AppColors.primary,
                  ),
                ],
              ),
            ),

            // Ảnh thu nhỏ nếu có
            if (hasImage)
              ClipRRect(
                child: _buildSafePostImage(msg.mediaUrl!, height: 140),
              ),

            // Nội dung bài viết tóm tắt
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                postContent,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: isMe ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),

            // Footer thanh nhấn để xem
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isDark ? AppColors.darkBorder : AppColors.border),
                    width: 0.6,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 13,
                    color: isMe ? Colors.white.withValues(alpha: 0.8) : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Nhấn để xem bài viết chi tiết',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white.withValues(alpha: 0.9) : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafePostImage(String url, {double height = 140}) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: height,
            color: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.broken_image_rounded),
          ),
        );
      } catch (_) {
        return Container(
          height: height,
          color: AppColors.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.broken_image_rounded),
        );
      }
    }
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: height,
        color: AppColors.primary.withValues(alpha: 0.15),
        child: const Icon(Icons.broken_image_rounded),
      ),
    );
  }
}
