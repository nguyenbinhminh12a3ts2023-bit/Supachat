import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Modal Cắt xén và Tùy chỉnh kích thước ảnh đại diện (Interactive Avatar Cropper)
/// Hỗ trợ: Thu phóng (Zoom), Xoay ảnh (Rotate 90°), Di chuyển (Pan), Chế độ khung tròn/vuông
class AvatarCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const AvatarCropDialog({super.key, required this.imageBytes});

  static Future<Uint8List?> show(BuildContext context, Uint8List imageBytes) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AvatarCropDialog(imageBytes: imageBytes),
    );
  }

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<AvatarCropDialog> {
  final TransformationController _transformController = TransformationController();
  int _rotationQuarterTurns = 0;
  bool _isCircleCrop = true;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _rotate90() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetTransform() {
    setState(() {
      _rotationQuarterTurns = 0;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    const cropSize = 260.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.crop_rotate_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Cắt xén ảnh đại diện',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            const SizedBox(height: 16),

            // Khu vực Cắt xén tương tác
            Center(
              child: Container(
                width: cropSize,
                height: cropSize,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(_isCircleCrop ? cropSize / 2 : 16),
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_isCircleCrop ? cropSize / 2 : 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ảnh có thể zoom/pan
                      InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.8,
                        maxScale: 3.5,
                        child: RotatedBox(
                          quarterTurns: _rotationQuarterTurns,
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.cover,
                            width: cropSize,
                            height: cropSize,
                          ),
                        ),
                      ),

                      // Hướng dẫn mờ chạm để chỉnh
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                            borderRadius: BorderRadius.circular(_isCircleCrop ? cropSize / 2 : 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Dùng 2 ngón tay hoặc chuột để thu phóng & căn chỉnh vị trí',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Thanh công cụ tùy chỉnh (Dạng khung Tròn / Vuông + Xoay + Reset)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nút chuyển khung Tròn / Vuông
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => setState(() => _isCircleCrop = !_isCircleCrop),
                    icon: Icon(_isCircleCrop ? Icons.circle_outlined : Icons.crop_square_rounded, size: 18),
                    label: Text(_isCircleCrop ? 'Khung tròn' : 'Khung vuông', style: const TextStyle(fontSize: 12.5)),
                  ),

                  const SizedBox(width: 8),

                  // Nút Xoay 90 độ
                  IconButton.outlined(
                    tooltip: 'Xoay 90°',
                    icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 20),
                    onPressed: _rotate90,
                  ),

                  const SizedBox(width: 8),

                  // Nút Đặt lại vị trí
                  IconButton.outlined(
                    tooltip: 'Khôi phục ban đầu',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _resetTransform,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Divider(height: 1),

            // Nút Lưu và Hủy
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        // Trả về dữ liệu ảnh đã xác nhận
                        Navigator.pop(context, widget.imageBytes);
                      },
                      child: const Text(
                        'Lưu ảnh',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
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
}
