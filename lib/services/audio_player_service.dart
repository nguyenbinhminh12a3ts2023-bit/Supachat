import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../constants/music_tracks.dart';

/// Dịch vụ phát nhạc thật toàn cầu (Global Audio Player Service)
class AudioPlayerService with ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  static AudioPlayerService get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  MusicTrack? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  MusicTrack? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

  AudioPlayerService._internal() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
  }

  /// Phát một bài hát THẬT trực tuyến từ URL, hỗ trợ tua đến đoạn mong muốn (startSeconds)
  Future<void> playTrack(MusicTrack track, {int startSeconds = 0}) async {
    try {
      if (_currentTrack?.id == track.id && _isPlaying && startSeconds == 0) {
        await pauseTrack();
        return;
      }

      _currentTrack = track;
      notifyListeners();

      await _player.stop();
      if (startSeconds > 0) {
        await _player.play(
          UrlSource(track.audioUrl),
          position: Duration(seconds: startSeconds),
        );
      } else {
        await _player.play(UrlSource(track.audioUrl));
      }
    } catch (e) {
      debugPrint('Lỗi phát nhạc: $e');
    }
  }

  /// Tua đến thời điểm chỉ định
  Future<void> seekTo(Duration targetPosition) async {
    try {
      await _player.seek(targetPosition);
    } catch (e) {
      debugPrint('Lỗi seek nhạc: $e');
    }
  }

  Future<void> pauseTrack() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Lỗi tạm dừng: $e');
    }
  }

  Future<void> resumeTrack() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('Lỗi tiếp tục phát: $e');
    }
  }

  Future<void> stopTrack() async {
    try {
      await _player.stop();
      _currentTrack = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi dừng phát nhạc: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
