import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/audio_player_service.dart';

/// Thanh phát nhạc mini chạy nền toàn ứng dụng (Global Music Player Bar)
class GlobalMusicPlayerBar extends StatelessWidget {
  const GlobalMusicPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = AudioPlayerService();

    return AnimatedBuilder(
      animation: audioService,
      builder: (context, _) {
        final track = audioService.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cover art
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  track.coverUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 40,
                    height: 40,
                    color: AppColors.primary,
                    child: const Icon(Icons.music_note, color: Colors.white, size: 20),
                  ),
                ),
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

              // Play / Pause button
              IconButton(
                icon: Icon(
                  audioService.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
                onPressed: () {
                  if (audioService.isPlaying) {
                    audioService.pauseTrack();
                  } else {
                    audioService.resumeTrack();
                  }
                },
              ),

              // Close button
              IconButton(
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

