import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Painter vẽ Logo SupaChat chuẩn thiết kế Figma
/// Gồm: Vòng tròn bong bóng hội thoại tối giản mềm mại + Làn sóng biển đôi nhẹ nhàng bên trong
class SupaChatLogoPainter extends CustomPainter {
  final List<Color> gradientColors;
  final bool hasGlow;
  final double strokeRatio;

  const SupaChatLogoPainter({
    this.gradientColors = const [
      AppColors.primary,
      AppColors.electricBlue,
      AppColors.primaryLight,
    ],
    this.hasGlow = false,
    this.strokeRatio = 0.12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.46);
    final radius = size.width * 0.38;
    final strokeWidth = size.width * strokeRatio;

    final rect = Rect.fromCircle(center: center, radius: radius * 1.2);
    final gradient = LinearGradient(
      colors: gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shader = gradient.createShader(rect);

    // 1. Vòng tròn bong bóng hội thoại tối giản (Speech Bubble)
    final bubblePath = Path();
    const startAngle = -math.pi * 0.60;
    const sweepAngle = math.pi * 1.45;

    bubblePath.addArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
    );

    // Đuôi hội thoại mềm mại ở góc dưới trái
    final tailTip = Offset(size.width * 0.16, size.height * 0.84);
    final tailBase = Offset(
      center.dx + radius * math.cos(startAngle + 0.08),
      center.dy + radius * math.sin(startAngle + 0.08),
    );

    bubblePath.quadraticBezierTo(size.width * 0.22, size.height * 0.68, tailTip.dx, tailTip.dy);
    bubblePath.quadraticBezierTo(size.width * 0.28, size.height * 0.82, tailBase.dx, tailBase.dy);

    final strokePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (hasGlow) {
      final glowPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(bubblePath, glowPaint);
    }

    canvas.drawPath(bubblePath, strokePaint);

    // 2. Làn sóng biển đôi bên trong trung tâm
    final wavePath1 = Path();
    final wavePath2 = Path();
    final w = size.width;
    final h = size.height;

    // Sóng trên
    wavePath1.moveTo(w * 0.32, h * 0.42);
    wavePath1.cubicTo(w * 0.42, h * 0.34, w * 0.52, h * 0.48, w * 0.68, h * 0.38);

    // Sóng dưới
    wavePath2.moveTo(w * 0.36, h * 0.54);
    wavePath2.cubicTo(w * 0.46, h * 0.46, w * 0.56, h * 0.60, w * 0.64, h * 0.50);

    final wavePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.95
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(wavePath1, wavePaint);
    canvas.drawPath(wavePath2, wavePaint);
  }

  @override
  bool shouldRepaint(covariant SupaChatLogoPainter oldDelegate) => false;
}

/// Widget hiển thị biểu tượng Logo SupaChat
class SupaChatIcon extends StatelessWidget {
  final double size;
  final bool hasGlow;
  final List<Color>? gradientColors;

  const SupaChatIcon({
    super.key,
    this.size = 48,
    this.hasGlow = false,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SupaChatLogoPainter(
          gradientColors: gradientColors ?? [
            AppColors.primary,
            AppColors.electricBlue,
            AppColors.primaryLight,
          ],
          hasGlow: hasGlow,
        ),
      ),
    );
  }
}

/// Widget Logo SupaChat kèm Chữ thương hiệu
class SupaChatLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showText;
  final bool isVertical;

  const SupaChatLogo({
    super.key,
    this.iconSize = 38,
    this.fontSize = 22,
    this.showText = true,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = SupaChatIcon(size: iconSize);

    if (!showText) return icon;

    final textWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => AppColors.logoHorizontalGradient.createShader(bounds),
          child: Text(
            'Supa',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'Chat',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
      ],
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(height: iconSize * 0.2),
          textWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        textWidget,
      ],
    );
  }
}

/// Widget App Icon Badge chuẩn Figma
class SupaChatAppIconBadge extends StatelessWidget {
  final double size;

  const SupaChatAppIconBadge({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = size * 0.28;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFD3E5EC),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SupaChatIcon(size: size * 0.65, hasGlow: false),
      ),
    );
  }
}
