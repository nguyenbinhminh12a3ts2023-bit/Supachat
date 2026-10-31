import 'real_call_audio_stub.dart'
    if (dart.library.html) 'real_call_audio_web.dart' as rcall;

class RealCallAudioHelper {
  static Future<void> startCallSession({
    required String callId,
    required bool isCaller,
    required Function(bool isConnected) onConnectedChange,
  }) =>
      rcall.RealCallAudioHelper.startCallSession(
        callId: callId,
        isCaller: isCaller,
        onConnectedChange: onConnectedChange,
      );

  static void setMute(bool isMuted) => rcall.RealCallAudioHelper.setMute(isMuted);

  static void endCallSession() => rcall.RealCallAudioHelper.endCallSession();
}

