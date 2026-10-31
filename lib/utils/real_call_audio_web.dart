// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RealCallAudioHelper {
  static html.MediaStream? _localStream;
  static html.RtcPeerConnection? _peerConnection;
  static html.AudioElement? _remoteAudio;
  static StreamSubscription? _callDocSub;
  static StreamSubscription? _candidateSub;

  /// Khởi tạo cuộc gọi thoại 2 chiều THẬT 100% bằng WebRTC chuẩn Google
  static Future<void> startCallSession({
    required String callId,
    required bool isCaller,
    required Function(bool isConnected) onConnectedChange,
  }) async {
    try {
      // 1. Lấy Microphone người dùng
      _localStream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      if (_localStream == null) {
        debugPrint('Không truy cập được Micro');
        return;
      }

      // 2. Tạo WebRTC Peer Connection với STUN server miễn phí của Google
      final rtcConfig = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      };
      _peerConnection = html.RtcPeerConnection(rtcConfig);

      // Thêm luồng âm thanh micro vào WebRTC
      for (final track in _localStream!.getAudioTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }

      // Lắng nghe luồng âm thanh từ phía bên kia và phát ra loa thật 100%
      _peerConnection!.addEventListener('track', (event) {
        try {
          final rtcTrackEvent = event as html.RtcTrackEvent;
          final streams = rtcTrackEvent.streams;
          if (streams != null && streams.isNotEmpty) {
            final remoteStream = streams[0];
            _remoteAudio ??= html.AudioElement();
            _remoteAudio!.srcObject = remoteStream;
            _remoteAudio!.autoplay = true;
            _remoteAudio!.play();
            onConnectedChange(true);
          }
        } catch (e) {
          debugPrint('Lỗi phát âm thanh remote: $e');
        }
      });

      // Lắng nghe trạng thái kết nối
      _peerConnection!.addEventListener('connectionstatechange', (event) {
        final state = _peerConnection?.connectionState;
        if (state == 'connected') {
          onConnectedChange(true);
        }
      });

      final callRef = FirebaseFirestore.instance.collection('calls').doc(callId);

      // 3. Xử lý ICE Candidate
      _peerConnection!.addEventListener('icecandidate', (event) {
        final rtcIceEvent = event as html.RtcPeerConnectionIceEvent;
        final candidate = rtcIceEvent.candidate;
        if (candidate != null) {
          final collectionName = isCaller ? 'callerCandidates' : 'calleeCandidates';
          callRef.collection(collectionName).add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      });

      final otherCandidatesCollection = isCaller ? 'calleeCandidates' : 'callerCandidates';
      _candidateSub = callRef.collection(otherCandidatesCollection).snapshots().listen((snapshot) {
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
                _peerConnection?.addIceCandidate(candidate);
              } catch (_) {}
            }
          }
        }
      });

      // 4. Quá trình trao đổi Offer / Answer
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
          if (data != null && data['answer'] != null && _peerConnection?.remoteDescription == null) {
            final answerData = data['answer'] as Map<String, dynamic>;
            await _peerConnection?.setRemoteDescription({
              'type': answerData['type'],
              'sdp': answerData['sdp'],
            });
            onConnectedChange(true);
          }
        });
      } else {
        _callDocSub = callRef.snapshots().listen((snapshot) async {
          final data = snapshot.data();
          if (data != null && data['offer'] != null && _peerConnection?.remoteDescription == null) {
            final offerData = data['offer'] as Map<String, dynamic>;
            await _peerConnection?.setRemoteDescription({
              'type': offerData['type'],
              'sdp': offerData['sdp'],
            });

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

    if (_remoteAudio != null) {
      _remoteAudio!.pause();
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
