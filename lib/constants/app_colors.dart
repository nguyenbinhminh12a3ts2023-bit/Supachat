import 'package:flutter/material.dart';

/// Bảng màu chuẩn theo thiết kế Figma của SupaChat
/// Tối: #10121C / #1B1E2C / Gradient Violet-Blue #6C5CE7 -> #4F8BFF
/// Sáng: #F7F8FC / #FFFFFF / #EEF0F8
class AppColors {
  // === Figma Brand Colors ===
  static const Color primary = Color(0xFF6C5CE7);           // Tím hoàng gia chuẩn Figma
  static const Color primaryDark = Color(0xFF5B4BC4);       // Tím đậm
  static const Color primaryLight = Color(0xFFA397FF);      // Lavender sáng (#A397FF)
  static const Color electricBlue = Color(0xFF4F8BFF);      // Xanh dương điện (#4F8BFF)
  static const Color accent = Color(0xFFA397FF);            // Lavender nhấn
  static const Color tealAccent = Color(0xFF00D1B2);        // Xanh ngọc online (#00D1B2)
  static const Color tealText = Color(0xFF54E3CF);          // Xanh ngọc trạng thái sáng (#54E3CF)
  static const Color accentGreen = Color(0xFF00D1B2);       // Xanh ngọc thành công
  static const Color coralDanger = Color(0xFFEF647A);       // Đỏ san hô / Gọi nhỡ / Đăng xuất (#EF647A)

  // Gradients chuẩn Figma (135 độ: #6C5CE7 -> #4F8BFF)
  static const Color gradientStart = Color(0xFF6C5CE7);
  static const Color gradientEnd = Color(0xFF4F8BFF);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF4F8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF4F8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient logoHorizontalGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF4F8BFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Gradient thẻ badge sáng
  static const LinearGradient lightBadgeGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // === Giao diện Sáng (Light Theme - Figma) ===
  static const Color background = Color(0xFFF7F8FC);        // Nền sáng (#F7F8FC)
  static const Color surface = Color(0xFFFFFFFF);           // Bề mặt thẻ trắng (#FFFFFF)
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFFEEF0F8);           // Nền nhập liệu sáng (#EEF0F8)
  static const Color inputBgAlt = Color(0xFFE7E9F2);        // Nền phụ
  static const Color lightLavender = Color(0xFFEEEBFF);     // Nền tím nhạt chọn lọc
  static const Color textPrimary = Color(0xFF1E1F2B);       // Chữ chính đen tím (#1E1F2B)
  static const Color textSecondary = Color(0xFF777D91);     // Chữ phụ xám (#777D91)
  static const Color textMuted = Color(0xFF9DA5BE);         // Chữ mờ
  static const Color border = Color(0xFFE7E9F2);            // Viền sáng (#E7E9F2)
  static const Color divider = Color(0xFFEEF0F8);

  // === Giao diện Tối (Dark Theme - Figma) ===
  static const Color darkBackground = Color(0xFF10121C);    // Nền tối sâu chuẩn Figma (#10121C)
  static const Color darkSurface = Color(0xFF1B1E2C);       // Bề mặt thẻ tối (#1B1E2C)
  static const Color darkCardColor = Color(0xFF1B1E2C);
  static const Color darkInputBg = Color(0xFF24283A);       // Nền nhập liệu tối (#24283A)
  static const Color darkSecondary = Color(0xFF292442);     // Hộp icon / nút phụ (#292442)
  static const Color darkBorder = Color(0xFF2B3043);        // Viền tối (#2B3043)
  static const Color darkTextPrimary = Color(0xFFF4F5FC);   // Chữ sáng (#F4F5FC)
  static const Color darkTextSecondary = Color(0xFF9DA5BE); // Chữ phụ xám (#9DA5BE)
  static const Color darkTextMuted = Color(0xFF6B7280);

  // Bong bóng chat
  static const Color senderBubble = Color(0xFF6C5CE7);      // Tím hoặc dùng brandGradient
  static const Color senderText = Colors.white;
  static const Color receiverBubble = Color(0xFFEEEBFF);    // Sáng: tím nhạt (#EEEBFF)
  static const Color receiverText = Color(0xFF1E1F2B);
  static const Color darkReceiverBubble = Color(0xFF24283A);// Tối: #24283A
  static const Color darkReceiverText = Color(0xFFF4F5FC);

  // Trạng thái & Tương thích ngược
  static const Color online = Color(0xFF00D1B2);           // Figma Teal (#00D1B2)
  static const Color onlineLight = Color(0xFF008C79);      // Teal trên nền sáng
  static const Color offline = Color(0xFF9DA5BE);
  static const Color error = Color(0xFFEF647A);            // Coral Red (#EF647A)
  static const Color success = Color(0xFF00D1B2);
  static const Color warning = Color(0xFFF59E0B);
}
