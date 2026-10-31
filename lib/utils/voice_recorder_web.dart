// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class VoiceRecorderHelper {
  static html.MediaStream? _stream;
  static html.MediaRecorder? _recorder;
  static final List<html.Blob> _chunks = [];
  static html.AudioElement? _currentAudio;
  static String? _playingUrl;
  static VoidCallback? _onEndedCallback;

  /// Bắt đầu thu âm giọng nói THẬT từ Microphone trình duyệt
  static Future<bool> startRecording() async {
    try {
      _chunks.clear();
      _stream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      if (_stream == null) return false;

      // Chọn mimeType hỗ trợ tốt nhất trên Chrome / Safari / Firefox
      String mimeType = 'audio/webm';
      if (!html.MediaRecorder.isTypeSupported('audio/webm')) {
        if (html.MediaRecorder.isTypeSupported('audio/mp4')) {
          mimeType = 'audio/mp4';
        } else if (html.MediaRecorder.isTypeSupported('audio/ogg')) {
          mimeType = 'audio/ogg';
        }
      }

      _recorder = html.MediaRecorder(_stream!, {'mimeType': mimeType});
      _recorder!.addEventListener('dataavailable', (event) {
        final blob = (event as html.BlobEvent).data;
        if (blob != null && blob.size > 0) {
          _chunks.add(blob);
        }
      });

      _recorder!.start(100); // chunk every 100ms
      return true;
    } catch (e) {
      debugPrint('Lỗi truy cập Micro: $e');
      return false;
    }
  }

  /// Dừng thu âm và trả về chuỗi âm thanh Base64 Data URL THẬT của người dùng
  static Future<String?> stopRecording() async {
    if (_recorder == null) return null;

    final completer = Completer<String?>();

    _recorder!.addEventListener('stop', (event) {
      try {
        final mime = _recorder?.mimeType ?? 'audio/webm';
        final fullBlob = html.Blob(_chunks, mime);

        final reader = html.FileReader();
        reader.readAsDataUrl(fullBlob);
        reader.onLoadEnd.listen((_) {
          final result = reader.result as String?;
          completer.complete(result);
        });
      } catch (e) {
        debugPrint('Lỗi xuất file ghi âm: $e');
        completer.complete(null);
      } finally {
        // Tắt micro (đèn đỏ mic trên tab biến mất)
        _stream?.getTracks().forEach((track) => track.stop());
        _stream = null;
        _recorder = null;
      }
    });

    try {
      _recorder!.stop();
    } catch (e) {
      _stream?.getTracks().forEach((track) => track.stop());
      _stream = null;
      _recorder = null;
      return null;
    }

    return completer.future;
  }

  /// Hủy bỏ bản thu âm hiện tại
  static void cancelRecording() {
    try {
      if (_recorder != null && _recorder!.state != 'inactive') {
        _recorder!.stop();
      }
    } catch (_) {}
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
    _recorder = null;
    _chunks.clear();
  }

  /// Phát âm thanh thật (Giọng nói thật của người dùng)
  static void playAudio(String audioUrl, {VoidCallback? onEnded, VoidCallback? onPlayStateChanged}) {
    if (_currentAudio != null) {
      _currentAudio!.pause();
      _currentAudio = null;
      if (_playingUrl == audioUrl) {
        _playingUrl = null;
        onPlayStateChanged?.call();
        return;
      }
    }

    _playingUrl = audioUrl;
    _currentAudio = html.AudioElement(audioUrl);
    _onEndedCallback = onEnded;

    _currentAudio!.onEnded.listen((_) {
      _playingUrl = null;
      _currentAudio = null;
      _onEndedCallback?.call();
      onPlayStateChanged?.call();
    });

    _currentAudio!.play();
    onPlayStateChanged?.call();
  }

  /// Dừng phát âm thanh
  static void stopAudio() {
    if (_currentAudio != null) {
      _currentAudio!.pause();
      _currentAudio = null;
    }
    _playingUrl = null;
  }

  /// Kiểm tra xem URL này có đang phát không
  static bool isAudioPlaying(String audioUrl) {
    return _playingUrl == audioUrl && _currentAudio != null && !_currentAudio!.paused;
  }
}
