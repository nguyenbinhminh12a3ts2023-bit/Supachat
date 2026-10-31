import 'package:flutter/foundation.dart';

class VoiceRecorderHelper {
  static Future<bool> startRecording() async => false;
  static Future<String?> stopRecording() async => null;
  static void cancelRecording() {}
  static void playAudio({
    required String messageId,
    required String audioUrl,
    VoidCallback? onEnded,
    VoidCallback? onPlayStateChanged,
    VoidCallback? onSampleOldMessage,
  }) {}
  static void stopAudio() {}
  static bool isMessagePlaying(String messageId) => false;
}
