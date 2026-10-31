class RealCallAudioHelper {
  static Future<void> startCallSession({
    required String callId,
    required bool isCaller,
    required Function(bool isConnected) onConnectedChange,
  }) async {}

  static void setMute(bool isMuted) {}
  static void endCallSession() {}
}

