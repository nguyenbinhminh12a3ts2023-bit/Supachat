import 'package:flutter/foundation.dart';

class VoiceRecorderHelper {
  static Future<bool> startRecording() async => false;
  static Future<String?> stopRecording() async => null;
  static void cancelRecording() {}
  static void playAudio(String audioUrl, {VoidCallback? onEnded, VoidCallback? onPlayStateChanged}) {}
  static void stopAudio() {}
  static bool isAudioPlaying(String audioUrl) => false;
}
