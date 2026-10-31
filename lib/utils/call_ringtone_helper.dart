import 'package:audioplayers/audioplayers.dart';

/// Tiện ích phát âm thanh chuông chờ và chuông reo cuộc gọi (Đa nền tảng)
class CallRingtoneHelper {
  static final AudioPlayer _player = AudioPlayer();

  // Tiếng chuông chờ cuộc gọi đi ("Tút... Tút..." ngắt quãng)
  static const String ringbackUrl =
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';

  // Tiếng chuông báo cuộc gọi đến
  static const String incomingUrl =
      'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3';

  /// Bắt đầu phát tiếng chuông chờ cuộc gọi đi
  static Future<void> startRingbackTone() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.5);
      await _player.play(UrlSource(ringbackUrl));
    } catch (_) {}
  }

  /// Bắt đầu phát tiếng chuông reo cuộc gọi đến
  static Future<void> startIncomingRingtone() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.8);
      await _player.play(UrlSource(incomingUrl));
    } catch (_) {}
  }

  /// Dừng mọi âm thanh chuông ngay lập tức
  static Future<void> stopAll() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
