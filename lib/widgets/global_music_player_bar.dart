import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/audio_player_service.dart';

/// Thanh phát nhạc mini chạy nền toàn ứng dụng chuẩn Figma (Global Floating Music Player)
class GlobalMusicPlayerBar extends StatefulWidget {
  const GlobalMusicPlayerBar({super.key});

  @override
  State<GlobalMusicPlayerBar> createState() => _GlobalMusicPlayerBarState();
}

class _GlobalMusicPlayerBarState extends State<GlobalMusicPlayerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioService = AudioPlayerService();

    return AnimatedBuilder(
      animation: audioService,
      builder: (context, _) {
        final track = audioService.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isPlaying = audioService.isPlaying;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Spinning Vinyl Disc / Cover art
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.network(
                      track.coverUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.music_note, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBackground : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Title & Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artist} · ${track.duration}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Figma Animated Waveform Bars
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  final t = isPlaying ? _waveController.value : 0.2;
                  final heights = [
                    4.0 + 8.0 * t,
                    12.0 - 6.0 * t,
                    6.0 + 10.0 * t,
                    14.0 - 8.0 * t,
                    5.0 + 9.0 * t,
                    10.0 - 5.0 * t,
                  ];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: heights.map((h) {
                      return Container(
                        width: 2.5,
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Play / Pause button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
                onPressed: () {
                  if (isPlaying) {
                    audioService.pauseTrack();
                  } else {
                    audioService.resumeTrack();
                  }
                },
              ),
              const SizedBox(width: 6),

              // Close button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                onPressed: () => audioService.stopTrack(),
              ),
            ],
          ),
        );
      },
    );
  }
}
