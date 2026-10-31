// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class VoiceRecorderHelper {
  static html.MediaStream? _stream;
  static html.MediaRecorder? _recorder;
  static final List<html.Blob> _chunks = [];
  static html.AudioElement? _currentAudio;
  static String? _playingMessageId;
  static String? _playingUrl;
  static String? _currentBlobUrl;
  static String? get playingUrl => _playingUrl;
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

        if (fullBlob.size == 0) {
          completer.complete(null);
          return;
        }

        final reader = html.FileReader();
        reader.readAsDataUrl(fullBlob);
        reader.onLoadEnd.listen((_) {
          final result = reader.result as String?;
          completer.complete(result);
        });
        reader.onError.listen((_) {
          completer.complete(null);
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
      // Đẩy nốt buffer âm thanh trước khi stop
      try {
        _recorder!.requestData();
      } catch (_) {}
      _recorder!.stop();
    } catch (e) {
      _stream?.getTracks().forEach((track) => track.stop());
      _stream = null;
      _recorder = null;
      return null;
    }

    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
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

  /// Chuyển đổi Data URL base64 sang Blob Object URL để AudioElement phát mượt mà nhất
  static String _resolveAudioUrl(String url) {
    if (url.startsWith('data:audio')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final header = url.substring(0, commaIdx);
          final base64Data = url.substring(commaIdx + 1);
          final mimeMatch = RegExp(r'data:(.*?);base64').firstMatch(header);
          final mimeType = mimeMatch?.group(1) ?? 'audio/webm';

          final bytes = base64Decode(base64Data);
          final blob = html.Blob([bytes], mimeType);
          return html.Url.createObjectUrl(blob);
        }
      } catch (e) {
        debugPrint('Lỗi tạo blob audio url: $e');
      }
    }
    return url;
  }

  /// Phát âm thanh thật (Giọng nói thật của người dùng) theo messageId riêng biệt
  static void playAudio({
    required String messageId,
    required String audioUrl,
    VoidCallback? onEnded,
    VoidCallback? onPlayStateChanged,
    VoidCallback? onSampleOldMessage,
  }) {
    // Nếu đang phát cùng 1 tin nhắn này -> Tạm dừng
    if (_currentAudio != null && _playingMessageId == messageId) {
      _currentAudio!.pause();
      _currentAudio = null;
      _playingMessageId = null;
      _playingUrl = null;
      _revokeCurrentBlob();
      onPlayStateChanged?.call();
      return;
    }

    // Dừng âm thanh khác đang phát nếu có
    if (_currentAudio != null) {
      _currentAudio!.pause();
      _currentAudio = null;
      _playingMessageId = null;
      _playingUrl = null;
      _revokeCurrentBlob();
    }

    // CHẶN TUYỆT ĐỐI KHÔNG PHÁT NHẠC MẪU SƠN TÙNG CŨ TRONG DATABASE
    if (audioUrl.contains('archive.org') ||
        audioUrl.contains('son-tung') ||
        audioUrl.contains('Binh%20Yen')) {
      _playingMessageId = null;
      _playingUrl = null;
      onSampleOldMessage?.call();
      onPlayStateChanged?.call();
      return;
    }

    _playingMessageId = messageId;
    _playingUrl = audioUrl;

    try {
      final playableUrl = _resolveAudioUrl(audioUrl);
      if (playableUrl.startsWith('blob:')) {
        _currentBlobUrl = playableUrl;
      }
      _currentAudio = html.AudioElement(playableUrl);
      _onEndedCallback = onEnded;

      _currentAudio!.onEnded.listen((_) {
        _playingMessageId = null;
        _playingUrl = null;
        _currentAudio = null;
        _revokeCurrentBlob();
        _onEndedCallback?.call();
        onPlayStateChanged?.call();
      });

      _currentAudio!.onError.listen((_) {
        _playingMessageId = null;
        _playingUrl = null;
        _currentAudio = null;
        _revokeCurrentBlob();
        onPlayStateChanged?.call();
      });

      _currentAudio!.play();
      onPlayStateChanged?.call();
    } catch (e) {
      debugPrint('Lỗi play audio: $e');
      _playingMessageId = null;
      _playingUrl = null;
      _currentAudio = null;
      _revokeCurrentBlob();
      onPlayStateChanged?.call();
    }
  }

  static void _revokeCurrentBlob() {
    if (_currentBlobUrl != null) {
      try {
        html.Url.revokeObjectUrl(_currentBlobUrl!);
      } catch (_) {}
      _currentBlobUrl = null;
    }
  }

  /// Dừng phát âm thanh
  static void stopAudio() {
    if (_currentAudio != null) {
      _currentAudio!.pause();
      _currentAudio = null;
    }
    _revokeCurrentBlob();
    _playingMessageId = null;
    _playingUrl = null;
  }

  /// Kiểm tra xem TIN NHẮN CỤ THỂ NÀY (theo messageId) có đang phát không
  static bool isMessagePlaying(String messageId) {
    return _playingMessageId == messageId && _currentAudio != null && !_currentAudio!.paused;
  }
}
