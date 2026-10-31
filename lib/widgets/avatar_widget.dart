import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Widget hiển thị ảnh đại diện với trạng thái Online/Offline
/// Mặc định: Avatar gradient SupaChat (User mới hoặc khi người dùng xóa avatar)
class AvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool showOnlineStatus;
  final bool isOnline;

  static const String defaultAvatarAsset = 'assets/images/default_avatar.png';

  const AvatarWidget({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.showOnlineStatus = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarContent;

    final hasCustomPhoto = photoUrl != null &&
        photoUrl!.trim().isNotEmpty &&
        !photoUrl!.contains('default_avatar');

    if (hasCustomPhoto) {
      if (photoUrl!.startsWith('data:image')) {
        try {
          final base64Str = photoUrl!.contains(',') ? photoUrl!.split(',').last : photoUrl!;
          final bytes = base64Decode(base64Str);
          avatarContent = CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {
          avatarContent = _buildDefaultAvatar();
        }
      } else {
        final cacheSize = (radius * 3).round();
        avatarContent = CachedNetworkImage(
          imageUrl: photoUrl!,
          memCacheWidth: cacheSize > 0 ? cacheSize : 120,
          memCacheHeight: cacheSize > 0 ? cacheSize : 120,
          maxWidthDiskCache: cacheSize * 2,
          maxHeightDiskCache: cacheSize * 2,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: radius,
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
            child: SizedBox(
              width: radius,
              height: radius,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => _buildDefaultAvatar(),
        );
      }
    } else {
      avatarContent = _buildDefaultAvatar();
    }

    if (!showOnlineStatus) {
      return avatarContent;
    }

    // Hiển thị chấm trạng thái online/offline
    return Stack(
      children: [
        avatarContent,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.55,
            height: radius * 0.55,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.online : AppColors.offline,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          defaultAvatarAsset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CustomPaint(
            size: Size(radius * 2, radius * 2),
            painter: const DefaultAvatarPainter(),
          ),
        ),
      ),
    );
  }
}

/// Painter vẽ avatar mặc định SupaChat chuẩn gradient xanh tím và silhouette người màu trắng
class DefaultAvatarPainter extends CustomPainter {
  const DefaultAvatarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // 1. Viền ngoài gradient (xanh lam sang tím)
    final ringWidth = size.width * 0.055;
    final ringPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2A72FF), Color(0xFFC026FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    canvas.drawCircle(center, r - ringWidth / 2, ringPaint);

    // 2. Vùng lõi bên trong viền
    final innerRadius = r - ringWidth - (size.width * 0.03);

    // 3. Màu nền gradient mềm (xanh nhạt sang tím hồng)
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF62B6FF), Color(0xFFB558FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, innerRadius, fillPaint);

    // Clip trong phạm vi innerRadius để vẽ silhouette người trắng
    canvas.save();
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.clipPath(clipPath);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 4. Đầu hình tròn màu trắng
    final headRadius = innerRadius * 0.38;
    final headCenter = Offset(center.dx, center.dy - innerRadius * 0.16);
    canvas.drawCircle(headCenter, headRadius, whitePaint);

    // 5. Phần thân/vai cong hình vòm màu trắng
    final bodyCenter = Offset(center.dx, center.dy + innerRadius * 0.95);
    final bodyRadius = innerRadius * 0.82;
    canvas.drawCircle(bodyCenter, bodyRadius, whitePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
