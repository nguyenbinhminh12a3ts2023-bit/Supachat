import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Bàn phím bảo mật có tính năng Đảo vị trí phím (Scrambled Keypad)
/// Dành cho bảo mật thao tác tay chống nhìn trộm (Anti-Shoulder Surfing & Keylogger Protection)
class SecureKeypadSheet extends StatefulWidget {
  final String title;
  final String description;
  final Function(String pin)? onCompleted;

  const SecureKeypadSheet({
    super.key,
    this.title = 'Bàn phím bảo mật',
    this.description = 'Nhập 6 chữ số để xác thực',
    this.onCompleted,
  });

  static Future<String?> show(BuildContext context, {String? title, String? description}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecureKeypadSheet(
        title: title ?? 'Bàn phím bảo mật',
        description: description ?? 'Nhập 6 chữ số để xác thực',
      ),
    );
  }

  @override
  State<SecureKeypadSheet> createState() => _SecureKeypadSheetState();
}

class _SecureKeypadSheetState extends State<SecureKeypadSheet> {
  String _currentPin = '';
  final List<int> _keys = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
  bool _autoShuffle = false;

  @override
  void initState() {
    super.initState();
    _shuffleKeys();
  }

  /// Đảo ngẫu nhiên vị trí các phím số
  void _shuffleKeys() {
    setState(() {
      _keys.shuffle();
    });
    HapticFeedback.lightImpact();
  }

  void _onKeyPress(int digit) {
    if (_currentPin.length < 6) {
      setState(() {
        _currentPin += digit.toString();
      });

      if (_autoShuffle) {
        _shuffleKeys();
      }

      if (_currentPin.length == 6) {
        widget.onCompleted?.call(_currentPin);
        Navigator.pop(context, _currentPin);
      }
    }
  }

  void _onBackspace() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _currentPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh kéo nhỏ
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header với icon khiên bảo mật
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded, color: AppColors.electricBlue, size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            if (widget.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],

            const SizedBox(height: 20),

            // Hiển thị các chấm PIN đã nhập
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppColors.primaryLight : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? AppColors.primaryLight : AppColors.textMuted,
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: AppColors.primaryLight.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // Nút bấm Đảo vị trí phím tắt & Switch tự động đảo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.25),
                    foregroundColor: AppColors.electricBlue,
                    side: const BorderSide(color: AppColors.electricBlue, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _shuffleKeys,
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: const Text(
                    'Đảo phím',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tự đảo',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Switch(
                      value: _autoShuffle,
                      activeTrackColor: AppColors.electricBlue,
                      onChanged: (val) {
                        setState(() => _autoShuffle = val);
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bàn phím số Grid 3 cột x 4 hàng
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                // Hàng cuối: Vị trí 9 là Clear, 10 là số cuối, 11 là Backspace
                if (index == 9) {
                  return _buildActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Xóa hết',
                    onTap: _onClear,
                  );
                } else if (index == 10) {
                  final digit = _keys[9];
                  return _buildKeyButton(digit);
                } else if (index == 11) {
                  return _buildActionButton(
                    icon: Icons.backspace_outlined,
                    label: 'Xóa',
                    onTap: _onBackspace,
                  );
                }

                final digit = _keys[index];
                return _buildKeyButton(digit);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(int digit) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onKeyPress(digit),
        splashColor: AppColors.electricBlue.withValues(alpha: 0.3),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              digit.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
