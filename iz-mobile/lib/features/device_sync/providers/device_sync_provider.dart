import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../messages/providers/chat_provider.dart';
import '../../../core/network/websocket_provider.dart';

final deviceSyncProvider = NotifierProvider<DeviceSyncNotifier, bool>(DeviceSyncNotifier.new);

class DeviceSyncNotifier extends Notifier<bool> {
  RTCPeerConnection? _pc;
  RTCDataChannel? _dataChannel;

  @override
  bool build() {
    return false; // is syncing
  }

  Future<void> handleOffer(Map<String, dynamic> payload) async {
    final sdpStr = payload['sdp'] as String;
    
    // Create peer connection
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    });

    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        ref.read(webSocketProvider)?.sendMessage('device_sync_candidate', {
          'candidate': jsonEncode(candidate.toMap())
        });
      }
    };

    _pc!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannel();
    };

    await _pc!.setRemoteDescription(RTCSessionDescription(sdpStr, 'offer'));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    ref.read(webSocketProvider)?.sendMessage('device_sync_answer', {
      'sdp': answer.sdp
    });
  }

  void handleAnswer(Map<String, dynamic> payload) async {
    final sdpStr = payload['sdp'] as String;
    await _pc?.setRemoteDescription(RTCSessionDescription(sdpStr, 'answer'));
  }

  void handleCandidate(Map<String, dynamic> payload) async {
    final candidateStr = payload['candidate'] as String;
    final Map<String, dynamic> candidateMap = jsonDecode(candidateStr);
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _pc?.addCandidate(candidate);
  }

  void _setupDataChannel() {
    _dataChannel?.onMessage = (RTCDataChannelMessage message) async {
      if (!message.isBinary) {
        try {
          final data = jsonDecode(message.text);
          if (data['type'] == 'get_history') {
            final chatId = data['chat_id'] as String;
            final repo = ref.read(messageRepositoryProvider);
            final messages = await repo.getMessages(chatId);
            
            _dataChannel?.send(RTCDataChannelMessage(jsonEncode({
              'type': 'history_response',
              'chat_id': chatId,
              'messages': messages.map((m) => m.toMap()).toList(),
            })));
          }
        } catch (e) {
          debugPrint('Error handling data channel msg: $e');
        }
      }
    };
  }

  void dispose() {
    _dataChannel?.close();
    _pc?.close();
  }
}
