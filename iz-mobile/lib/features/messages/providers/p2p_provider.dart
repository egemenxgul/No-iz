import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/network/websocket_provider.dart';
import 'chat_provider.dart';
import 'message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../call/providers/call_provider.dart';

final p2pProvider = NotifierProvider<P2PNotifier, Map<String, bool>>(P2PNotifier.new);

class P2PNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    final webrtc = ref.read(webrtcServiceProvider);
    
    // Listen for incoming P2P data messages
    webrtc.onDataMessage = (peerId, messagePayload) {
      try {
        final data = jsonDecode(messagePayload) as Map<String, dynamic>;
        _handleIncomingP2PMessage(peerId, data);
      } catch (e) {
        debugPrint('Failed to parse incoming P2P message: $e');
      }
    };
    
    return {};
  }

  void _handleIncomingP2PMessage(String peerId, Map<String, dynamic> payload) {
    final activeUserId = ref.read(authProvider).userId ?? '';
    final messageId = payload['id'] as String? ?? '';
    
    final mapped = {
      'id': messageId,
      'conversation_id': peerId,
      'sender_id': peerId,
      'recipient_id': activeUserId,
      'ciphertext': payload['ciphertext'],
      'plaintext': null,
      'msg_type': payload['msg_type'] ?? 'text',
      'ratchet_key': payload['ratchet_key'],
      'alice_identity_key': payload['alice_identity_key'],
      'alice_ephemeral_key': payload['alice_ephemeral_key'],
      'prev_counter': payload['prev_counter'],
      'counter': payload['counter'],
      'created_at': payload['created_at'] ?? DateTime.now().toIso8601String(),
      'expires_at': payload['expires_at'],
    };
    final msg = MessageModel.fromMap(mapped);

    ref.read(chatProvider(peerId).notifier).receiveMessage(msg);
  }

  Future<void> establishP2P(String peerId) async {
    if (state[peerId] == true) return; // Already establishing or established
    
    final webrtc = ref.read(webrtcServiceProvider);
    state = {...state, peerId: true};

    try {
      final offer = await webrtc.createDataOffer(peerId, (candidate) {
        _sendSignaling(peerId, 'p2p_message_ice', {
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      });

      _sendSignaling(peerId, 'p2p_message_offer', {
        'sdp': offer.sdp,
      });
    } catch (e) {
      debugPrint('Error establishing P2P: $e');
      state = {...state, peerId: false};
    }
  }

  Future<void> handleOffer(String peerId, String sdp) async {
    final webrtc = ref.read(webrtcServiceProvider);
    
    try {
      final answer = await webrtc.acceptDataOffer(peerId, sdp, (candidate) {
        _sendSignaling(peerId, 'p2p_message_ice', {
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      });

      _sendSignaling(peerId, 'p2p_message_answer', {
        'sdp': answer.sdp,
      });
      
      state = {...state, peerId: true};
    } catch (e) {
      debugPrint('Error handling P2P offer: $e');
    }
  }

  Future<void> handleAnswer(String peerId, String sdp) async {
    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.setAnswer(peerId, sdp);
    state = {...state, peerId: true};
  }

  Future<void> handleIceCandidate(String peerId, Map<String, dynamic> candidateMap) async {
    final webrtc = ref.read(webrtcServiceProvider);
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await webrtc.addCandidate(peerId, candidate);
  }

  Future<bool> sendP2PMessage(String peerId, Map<String, dynamic> payload) async {
    final webrtc = ref.read(webrtcServiceProvider);
    final text = jsonEncode(payload);
    return await webrtc.sendDataMessage(peerId, text);
  }

  void _sendSignaling(String targetId, String type, Map<String, dynamic> payload) {
    final wsService = ref.read(webSocketProvider);
    if (wsService != null) {
      wsService.sendMessage(type, {
        'target_id': targetId,
        'from_id': ref.read(authProvider).userId,
        ...payload,
      });
    }
  }
}
