import 'package:flutter/foundation.dart';
import 'voice_recorder_stub.dart'
    if (dart.library.html) 'voice_recorder_web.dart' as vrec;

/// Tiện ích thu âm micro thật và phát tin nhắn thoại 100% tiếng nói thực
class VoiceRecorderHelper {
  static Future<bool> startRecording() => vrec.VoiceRecorderHelper.startRecording();
  static Future<String?> stopRecording() => vrec.VoiceRecorderHelper.stopRecording();
  static void cancelRecording() => vrec.VoiceRecorderHelper.cancelRecording();
  static void playAudio(String audioUrl, {VoidCallback? onEnded, VoidCallback? onPlayStateChanged}) =>
      vrec.VoiceRecorderHelper.playAudio(audioUrl, onEnded: onEnded, onPlayStateChanged: onPlayStateChanged);
  static void stopAudio() => vrec.VoiceRecorderHelper.stopAudio();
  static bool isAudioPlaying(String audioUrl) => vrec.VoiceRecorderHelper.isAudioPlaying(audioUrl);
}
