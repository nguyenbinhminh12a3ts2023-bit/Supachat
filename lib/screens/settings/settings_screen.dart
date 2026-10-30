import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/secure_keypad_sheet.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';

/// Màn hình Cài đặt chuẩn Figma (Screen 18: Cài đặt)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _showOnlineStatus = true;
  bool _readReceiptsEnabled = true;
  final List<String> _blockedUsers = ['spammer_bot@test.com'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('supachat_notifications_enabled') ?? true;
        _showOnlineStatus = prefs.getBool('supachat_show_online_status') ?? true;
        _readReceiptsEnabled = prefs.getBool('supachat_read_receipts') ?? true;
      });
    }
  }

  Future<void> _updateNotificationPref(bool val) async {
    setState(() => _notificationsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('supachat_notifications_enabled', val);
  }

  Future<void> _updateOnlineStatusPref(bool val) async {
    setState(() => _showOnlineStatus = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('supachat_show_online_status', val);
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.updateOnlineStatus(val);
    }
  }

  Future<void> _updateReadReceiptsPref(bool val) async {
    setState(() => _readReceiptsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('supachat_read_receipts', val);
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? localError;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mật khẩu phải có ít nhất 6 ký tự để bảo vệ an toàn tài khoản của bạn.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  if (localError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.coralDanger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.coralDanger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.coralDanger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localError!,
                              style: const TextStyle(color: AppColors.coralDanger, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Mật khẩu hiện tại
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu hiện tại';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Mật khẩu mới
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                      if (val.length < 6) return 'Mật khẩu mới phải từ 6 ký tự trở lên';
                      if (val == currentPasswordController.text) {
                        return 'Mật khẩu mới không được trùng mật khẩu cũ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Xác nhận mật khẩu mới
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (val) {
                      if (val != newPasswordController.text) return 'Mật khẩu xác nhận không khớp';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSubmitting = true;
                        localError = null;
                      });

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final success = await authProvider.changePassword(
                        currentPassword: currentPasswordController.text,
                        newPassword: newPasswordController.text,
                      );

                      if (!ctx.mounted) return;

                      if (success) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đổi mật khẩu thành công! Hãy ghi nhớ mật khẩu mới của bạn.'),
                            backgroundColor: AppColors.accentGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        setDialogState(() {
                          isSubmitting = false;
                          localError = authProvider.errorMessage ?? 'Không thể đổi mật khẩu. Vui lòng thử lại.';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu mật khẩu mới', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockedUsersDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Danh sách đã chặn',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: _blockedUsers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Chưa có người dùng nào bị chặn',
                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _blockedUsers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final email = _blockedUsers[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.block, color: AppColors.coralDanger, size: 20),
                        title: Text(email, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary, fontSize: 14)),
                        trailing: TextButton(
                          onPressed: () {
                            setDialogState(() => _blockedUsers.removeAt(index));
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã bỏ chặn $email'), behavior: SnackBarBehavior.floating),
                            );
                          },
                          child: const Text('Bỏ chặn', style: TextStyle(color: AppColors.primary)),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quyền riêng tư & Bảo mật',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Hiển thị trạng thái Online', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                subtitle: Text('Cho phép bạn bè biết khi bạn đang trực tuyến', style: TextStyle(fontSize: 12, color: textSecondary)),
                value: _showOnlineStatus,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  _updateOnlineStatusPref(val);
                  setSheetState(() {});
                },
              ),
              Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Biên nhận đã đọc', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                subtitle: Text('Hiển thị dấu tích kép xanh khi bạn đã đọc tin nhắn', style: TextStyle(fontSize: 12, color: textSecondary)),
                value: _readReceiptsEnabled,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  _updateReadReceiptsPref(val);
                  setSheetState(() {});
                },
              ),
              Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_rounded, color: AppColors.primary),
                title: Text('Khóa ứng dụng bằng mã PIN', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                subtitle: Text('Bàn phím bảo mật đảo phím chống nhìn trộm', style: TextStyle(fontSize: 12, color: textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  SecureKeypadSheet.show(
                    context,
                    title: 'Khóa bảo mật SupaChat',
                    description: 'Thiết lập mã PIN 6 số an toàn',
                  );
                },
              ),
              Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block_rounded, color: AppColors.coralDanger),
                title: Text('Danh sách chặn (${_blockedUsers.length})', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                subtitle: Text('Quản lý người dùng đã bị chặn', style: TextStyle(fontSize: 12, color: textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlockedUsersDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<LocaleProvider>(
        builder: (ctx, loc, _) {
          final currentCode = loc.languageCode;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  loc.t('Chọn ngôn ngữ', 'Select Language', '言語を選択', '언어 선택'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _buildLanguageItem(ctx, loc, 'vi', 'Tiếng Việt', '🇻🇳', currentCode == 'vi', isDark),
                _buildLanguageItem(ctx, loc, 'en', 'English', '🇬🇧', currentCode == 'en', isDark),
                _buildLanguageItem(ctx, loc, 'ja', '日本語 (Japanese)', '🇯🇵', currentCode == 'ja', isDark),
                _buildLanguageItem(ctx, loc, 'ko', '한국어 (Korean)', '🇰🇷', currentCode == 'ko', isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext ctx,
    LocaleProvider loc,
    String code,
    String name,
    String flag,
    bool isSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () async {
        await loc.setLanguage(code);
        if (ctx.mounted) Navigator.pop(ctx);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('Đã chuyển ngôn ngữ sang \$name', 'Language changed to \$name')),
              backgroundColor: AppColors.accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkSecondary : AppColors.lightLavender)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Đăng xuất',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản SupaChat không?',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coralDanger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final user = authProvider.currentUserModel;

    final isDark = themeProvider.isDarkMode;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final displayName = user?.displayName != null && user!.displayName.isNotEmpty ? user.displayName : 'Minh An';
    final avatarUrl = user?.photoUrl;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tiêu đề trang
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Cài đặt',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Thẻ tài khoản (Account card Figma - 20px radius)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      // Avatar với chấm online
                      AvatarWidget(
                        photoUrl: avatarUrl,
                        name: displayName,
                        radius: 28,
                        showOnlineStatus: true,
                        isOnline: true,
                      ),
                      const SizedBox(width: 14),

                      // Thông tin tài khoản
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Xem trang cá nhân của bạn',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(Icons.chevron_right_rounded, color: textSecondary, size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. TRẢI NGHIỆM CỦA BẠN (Figma exact heading)
              Text(
                'TRẢI NGHIỆM CỦA BẠN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Column(
                  children: [
                    // Chế độ tối
                    _buildSettingsTile(
                      icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      title: 'Chế độ tối',
                      subtitle: isDark ? 'Đang bật' : 'Đang tắt',
                      trailing: Switch.adaptive(
                        value: isDark,
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                        onChanged: (val) {
                          themeProvider.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                        },
                      ),
                      isDark: isDark,
                      onTap: () {
                        themeProvider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                      },
                    ),
                    Divider(height: 1, thickness: 0.8, color: borderColor, indent: 56),
                    // Ngôn ngữ (Hỗ trợ đổi tiếng Việt, Anh, Nhật, Hàn)
                    _buildSettingsTile(
                      icon: Icons.language_rounded,
                      title: localeProvider.t('Ngôn ngữ', 'Language', '言語', '언어'),
                      subtitle: localeProvider.languageName,
                      trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                      isDark: isDark,
                      onTap: () => _showLanguageSheet(context),
                    ),
                    Divider(height: 1, thickness: 0.8, color: borderColor, indent: 56),
                    // Thông báo
                    _buildSettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Thông báo',
                      subtitle: _notificationsEnabled ? 'Đang bật' : 'Đang tắt',
                      trailing: Switch.adaptive(
                        value: _notificationsEnabled,
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                        onChanged: (val) => _updateNotificationPref(val),
                      ),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. RIÊNG TƯ & BẢO MẬT (Figma exact heading)
              Text(
                'RIÊNG TƯ & BẢO MẬT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Column(
                  children: [
                    // Bảo mật & Khóa PIN
                    _buildSettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Bảo mật & Khóa PIN',
                      subtitle: 'Đã bật',
                      trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                      isDark: isDark,
                      onTap: () async {
                        final pin = await SecureKeypadSheet.show(
                          context,
                          title: 'Xác thực mã PIN bảo vệ',
                          description: 'Nhập mã PIN gồm 6 số để quản lý bảo mật',
                        );
                        if (pin != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mã PIN xác thực thành công!'),
                              backgroundColor: AppColors.accentGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    Divider(height: 1, thickness: 0.8, color: borderColor, indent: 56),
                    // Quyền riêng tư
                    _buildSettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Quyền riêng tư',
                      subtitle: 'Kiểm soát ai có thể xem tin & bài viết của bạn',
                      trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                      isDark: isDark,
                      onTap: () => _showPrivacySheet(context),
                    ),
                    Divider(height: 1, thickness: 0.8, color: borderColor, indent: 56),
                    // Đổi mật khẩu
                    _buildSettingsTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Đổi mật khẩu',
                      subtitle: 'Đổi mật khẩu tài khoản SupaChat',
                      trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                      isDark: isDark,
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Nút Đăng xuất chuẩn Figma (Logout card - 20px radius)
              GestureDetector(
                onTap: () => _showLogoutDialog(context, authProvider),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF35212D) : const Color(0xFFFDECEF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.coralDanger.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: AppColors.coralDanger, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.coralDanger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bản quyền footer chuẩn Figma
              Center(
                child: Text(
                  'SupaChat 1.0.0 · Được tạo nên từ những kết nối 💜',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondary : AppColors.lightLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
