// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/firestore_helper.dart';

class RealCallAudioHelper {
  static html.MediaStream? _localStream;
  static html.RtcPeerConnection? _peerConnection;
  static html.AudioElement? _remoteAudio;
  static StreamSubscription? _callDocSub;
  static StreamSubscription? _candidateSub;
  static final List<html.RtcIceCandidate> _queuedRemoteCandidates = [];
  static bool _hasRemoteDescription = false;

  /// Khởi tạo cuộc gọi thoại 2 chiều THẬT 100% bằng WebRTC chuẩn Google
  static Future<void> startCallSession({
    required String callId,
    required bool isCaller,
    required Function(bool isConnected) onConnectedChange,
  }) async {
    try {
      _hasRemoteDescription = false;
      _queuedRemoteCandidates.clear();

      // 1. Yêu cầu quyền Micro người dùng
      _localStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
      });

      if (_localStream == null) {
        debugPrint('Không truy cập được Micro');
        return;
      }

      // 2. Tạo WebRTC Peer Connection với danh sách STUN server toàn cầu
      final rtcConfig = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
          {'urls': 'stun:stun4.l.google.com:19302'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
        ],
        'iceCandidatePoolSize': 10,
      };

      _peerConnection = html.RtcPeerConnection(rtcConfig);

      // Thêm luồng âm thanh micro vào WebRTC
      for (final track in _localStream!.getAudioTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }

      // 3. Xử lý nhận luồng âm thanh từ phía đối phương và phát ra loa
      void attachRemoteStream(html.MediaStream remoteStream) {
        try {
          if (_remoteAudio == null) {
            _remoteAudio = html.AudioElement()
              ..autoplay = true
              ..controls = false
              ..style.display = 'none';
            html.document.body?.append(_remoteAudio!);
          }
          _remoteAudio!.srcObject = remoteStream;
          _remoteAudio!.play().catchError((e) {
            debugPrint('Lỗi play remote audio: $e');
          });
          onConnectedChange(true);
        } catch (e) {
          debugPrint('Lỗi attach remote stream: $e');
        }
      }

      // Lắng nghe sự kiện track (chuẩn hiện đại)
      _peerConnection!.addEventListener('track', (event) {
        try {
          final rtcTrackEvent = event as html.RtcTrackEvent;
          final streams = rtcTrackEvent.streams;
          if (streams != null && streams.isNotEmpty) {
            attachRemoteStream(streams[0]);
          }
        } catch (e) {
          debugPrint('Lỗi track event: $e');
        }
      });

      // Dự phòng sự kiện onAddStream cho trình duyệt cũ
      _peerConnection!.onAddStream.listen((event) {
        final stream = event.stream;
        if (stream != null) {
          attachRemoteStream(stream);
        }
      });

      // Lắng nghe trạng thái kết nối WebRTC
      _peerConnection!.addEventListener('connectionstatechange', (_) {
        final state = _peerConnection?.connectionState;
        if (state == 'connected') {
          onConnectedChange(true);
        }
      });

      _peerConnection!.addEventListener('iceconnectionstatechange', (_) {
        final state = _peerConnection?.iceConnectionState;
        if (state == 'connected' || state == 'completed') {
          onConnectedChange(true);
        }
      });

      final callRef = AppFirestore.instance.collection('calls').doc(callId);

      // 4. Gửi ICE Candidates của bản thân lên Firestore
      _peerConnection!.addEventListener('icecandidate', (event) {
        final rtcIceEvent = event as html.RtcPeerConnectionIceEvent;
        final candidate = rtcIceEvent.candidate;
        if (candidate != null && candidate.candidate != null) {
          final collectionName = isCaller ? 'callerCandidates' : 'calleeCandidates';
          callRef.collection(collectionName).add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      });

      // Hàm drain hàng đợi ICE candidates sau khi đã setRemoteDescription
      Future<void> drainQueuedCandidates() async {
        _hasRemoteDescription = true;
        for (final candidate in _queuedRemoteCandidates) {
          try {
            await _peerConnection?.addIceCandidate(candidate);
          } catch (_) {}
        }
        _queuedRemoteCandidates.clear();
      }

      // 5. Lắng nghe ICE Candidates từ phía đối phương
      final otherCandidatesCollection = isCaller ? 'calleeCandidates' : 'callerCandidates';
      _candidateSub = callRef.collection(otherCandidatesCollection).snapshots().listen((snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && data['candidate'] != null) {
              try {
                final candidate = html.RtcIceCandidate({
                  'candidate': data['candidate'],
                  'sdpMid': data['sdpMid'],
                  'sdpMLineIndex': data['sdpMLineIndex'],
                });

                if (_hasRemoteDescription && _peerConnection != null) {
                  await _peerConnection?.addIceCandidate(candidate);
                } else {
                  _queuedRemoteCandidates.add(candidate);
                }
              } catch (_) {}
            }
          }
        }
      });

      // 6. Quá trình trao đổi Offer / Answer
      if (isCaller) {
        final offer = await _peerConnection!.createOffer({'offerToReceiveAudio': true});
        await _peerConnection!.setLocalDescription({'type': offer.type, 'sdp': offer.sdp});

        await callRef.set({
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          }
        }, SetOptions(merge: true));

        _callDocSub = callRef.snapshots().listen((snapshot) async {
          final data = snapshot.data();
          if (data != null && data['answer'] != null && !_hasRemoteDescription && _peerConnection != null) {
            final answerData = data['answer'] as Map<String, dynamic>;
            await _peerConnection?.setRemoteDescription({
              'type': answerData['type'],
              'sdp': answerData['sdp'],
            });
            await drainQueuedCandidates();
            onConnectedChange(true);
          }
        });
      } else {
        _callDocSub = callRef.snapshots().listen((snapshot) async {
          final data = snapshot.data();
          if (data != null && data['offer'] != null && !_hasRemoteDescription && _peerConnection != null) {
            final offerData = data['offer'] as Map<String, dynamic>;
            await _peerConnection?.setRemoteDescription({
              'type': offerData['type'],
              'sdp': offerData['sdp'],
            });
            await drainQueuedCandidates();

            final answer = await _peerConnection!.createAnswer();
            await _peerConnection!.setLocalDescription({'type': answer.type, 'sdp': answer.sdp});

            await callRef.update({
              'answer': {
                'type': answer.type,
                'sdp': answer.sdp,
              },
              'status': 'accepted',
            });
            onConnectedChange(true);
          }
        });
      }
    } catch (e) {
      debugPrint('Lỗi WebRTC Voice Call: $e');
    }
  }

  /// Bật / Tắt Mic
  static void setMute(bool isMuted) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  /// Kết thúc cuộc gọi thật
  static void endCallSession() {
    _callDocSub?.cancel();
    _callDocSub = null;
    _candidateSub?.cancel();
    _candidateSub = null;
    _queuedRemoteCandidates.clear();
    _hasRemoteDescription = false;

    if (_remoteAudio != null) {
      try {
        _remoteAudio!.pause();
        _remoteAudio!.srcObject = null;
        _remoteAudio!.remove();
      } catch (_) {}
      _remoteAudio = null;
    }

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.stop();
      }
      _localStream = null;
    }

    if (_peerConnection != null) {
      try {
        _peerConnection!.close();
      } catch (_) {}
      _peerConnection = null;
    }
  }
}
