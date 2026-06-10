import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/webrtc_service.dart';
import '../../../core/network/websocket_provider.dart';
import '../models/call_session.dart';
import '../../messages/providers/chat_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/message_model.dart';
import '../../messages/providers/message_repository.dart';

final webrtcServiceProvider = Provider<WebrtcService>((ref) {
  final service = WebrtcService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class CallNotifier extends Notifier<CallSession?> {
  @override
  CallSession? build() {
    // Bind remote renderer callbacks to reactively update session state
    final webrtc = ref.read(webrtcServiceProvider);
    webrtc.onRemoteRendererAdded = (peerId, renderer) {
      final current = state;
      if (current != null) {
        final updatedParticipants = Set<String>.from(current.activeParticipants)..add(peerId);
        final updatedNames = Map<String, String>.from(current.peerNames);
        if (!updatedNames.containsKey(peerId)) {
          updatedNames[peerId] = _resolvePeerName(peerId);
        }
        state = current.copyWith(
          activeParticipants: updatedParticipants.toList(),
          peerNames: updatedNames,
        );
      }
    };

    webrtc.onRemoteRendererRemoved = (peerId) {
      final current = state;
      if (current != null) {
        final updatedParticipants = List<String>.from(current.activeParticipants)..remove(peerId);
        state = current.copyWith(
          activeParticipants: updatedParticipants,
        );
      }
    };

    return null;
  }

  String _resolvePeerName(String userId) {
    try {
      final conversations = ref.read(conversationProvider);
      final match = conversations.firstWhere((c) => c.otherUserId == userId);
      return match.otherDisplayName ?? match.otherUsername;
    } catch (_) {
      return 'Kullanıcı ($userId)';
    }
  }

  /// Initiates an outgoing 1-1 call to the specified peer.
  Future<void> startCall({
    required String peerId,
    required String peerName,
    required CallType type,
  }) async {
    if (state != null) {
      if (kDebugMode) debugPrint('[CallProvider] Already in an active session.');
      return;
    }

    state = CallSession(
      callId: '', // Server-assigned callId is unknown at this point
      peerId: peerId,
      peerName: peerName,
      type: type,
      status: CallStatus.dialing,
      isGroup: false,
      activeParticipants: [peerId],
      peerNames: {peerId: peerName},
    );

    final webrtc = ref.read(webrtcServiceProvider);

    try {
      await webrtc.initializeRenderers();

      final offer = await webrtc.createOffer(
        peerId,
        type == CallType.video,
        (candidate) {
          _sendSignalingEvent('ice_candidate', {
            'call_id': state?.callId ?? '',
            'target_id': peerId,
            'candidate': jsonEncode({
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }),
          });
        },
      );

      final ws = ref.read(webSocketProvider);
      if (ws == null || !ws.isConnected) {
        throw Exception('Bağlantı yok. Arama başlatılamadı.');
      }

      ws.sendMessage('call_offer', {
        'callee_id': peerId,
        'call_type': type == CallType.audio ? 'audio' : 'video',
        'sdp': offer.sdp,
      });

      if (kDebugMode) debugPrint('[CallProvider] Call offer sent to $peerId');
    } catch (e) {
      if (kDebugMode) debugPrint('[CallProvider] Error starting call: $e');
      cleanup();
    }
  }

  /// Initiates a group call or promotes an existing 1-1 call to a group call.
  Future<void> startGroupCall({
    required String groupId,
    required List<String> members,
    required CallType type,
  }) async {
    if (state != null) {
      if (kDebugMode) debugPrint('[CallProvider] Already in an active session.');
      return;
    }

    final callId = const Uuid().v4();
    final names = <String, String>{};
    for (final member in members) {
      names[member] = _resolvePeerName(member);
    }

    state = CallSession(
      callId: callId,
      peerId: groupId,
      peerName: 'Grup Araması',
      type: type,
      status: CallStatus.active,
      isGroup: true,
      groupId: groupId,
      activeParticipants: const [],
      peerNames: names,
      startTime: DateTime.now(),
    );

    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.initializeRenderers();

    // Send group_call_join to register ourselves
    _sendSignalingEvent('group_call_join', {
      'call_id': callId,
      'group_id': groupId,
    });

    // Send group call offers to all other members in mesh
    for (final member in members) {
      _inviteGroupMember(callId, member, type);
    }
  }

  /// Promotes a 1-1 call or invites another user to an active group call.
  Future<void> inviteParticipant(String peerId) async {
    final current = state;
    if (current == null) return;

    final name = _resolvePeerName(peerId);

    if (!current.isGroup) {
      // ─── 1-1 to Group Promotion ──────────────────────────────────────────
      final newCallId = const Uuid().v4();
      final currentPeer = current.peerId;

      if (kDebugMode) debugPrint('[CallProvider] Promoting 1-1 call with $currentPeer to group call $newCallId. Adding $peerId.');

      // Notify current 1-1 peer of promotion
      _sendSignalingEvent('call_promote', {
        'call_id': newCallId,
        'target_id': currentPeer,
      });

      // Tear down 1-1 WebRTC connection
      final webrtc = ref.read(webrtcServiceProvider);
      await webrtc.closePeerConnection(currentPeer);

      // Transition local state to Group Call
      state = current.copyWith(
        callId: newCallId,
        groupId: newCallId,
        peerId: '', // No single peer
        peerName: 'Grup Araması',
        isGroup: true,
        activeParticipants: [],
        peerNames: {
          currentPeer: current.peerName,
          peerId: name,
        },
      );

      // Join new group call on backend
      _sendSignalingEvent('group_call_join', {
        'call_id': newCallId,
        'group_id': '',
      });

      // Offer mesh connections to current peer and new peer
      _inviteGroupMember(newCallId, currentPeer, current.type);
      _inviteGroupMember(newCallId, peerId, current.type);
    } else {
      // ─── Add Member to Existing Group ──────────────────────────────────────
      final updatedNames = Map<String, String>.from(current.peerNames)..[peerId] = name;
      state = current.copyWith(peerNames: updatedNames);

      _inviteGroupMember(current.callId, peerId, current.type);
    }
  }

  Future<void> _inviteGroupMember(String callId, String targetId, CallType type) async {
    final webrtc = ref.read(webrtcServiceProvider);
    try {
      final offer = await webrtc.createOffer(
        targetId,
        type == CallType.video,
        (candidate) {
          _sendSignalingEvent('ice_candidate', {
            'call_id': callId,
            'target_id': targetId,
            'candidate': jsonEncode({
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }),
          });
        },
      );

      _sendSignalingEvent('group_call_offer', {
        'group_id': state?.groupId ?? '',
        'call_type': type == CallType.audio ? 'audio' : 'video',
        'sdp': offer.sdp,
        'target_id': targetId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[CallProvider] Error inviting member $targetId: $e');
    }
  }

  /// Handles incoming call signal received from the WebSocket.
  Future<void> receiveOffer({
    required String callId,
    required String callerId,
    required String sdp,
    required CallType type,
  }) async {
    if (state != null) {
      if (kDebugMode) debugPrint('[CallProvider] Busy. Rejecting incoming call: $callId');
      _sendSignalingEvent('call_reject', {
        'call_id': callId,
        'reason': 'busy',
      });
      return;
    }

    final peerName = _resolvePeerName(callerId);

    state = CallSession(
      callId: callId,
      peerId: callerId,
      peerName: peerName,
      type: type,
      status: CallStatus.ringing,
      isGroup: false,
      activeParticipants: [callerId],
      peerNames: {callerId: peerName},
    );

    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.initializeRenderers();

    _incomingSdp = sdp;
  }

  String? _incomingSdp;

  /// Accepts the incoming call.
  Future<void> acceptCall() async {
    final currentSession = state;
    if (currentSession == null || currentSession.status != CallStatus.ringing) {
      return;
    }

    state = currentSession.copyWith(
      status: CallStatus.active,
      startTime: DateTime.now(),
    );

    final webrtc = ref.read(webrtcServiceProvider);

    try {
      if (currentSession.isGroup) {
        // Joining group call
        _sendSignalingEvent('group_call_join', {
          'call_id': currentSession.callId,
          'group_id': currentSession.groupId ?? '',
        });
      } else {
        if (_incomingSdp == null) return;
        // Accepting 1-1 call
        final answer = await webrtc.acceptOffer(
          currentSession.peerId,
          _incomingSdp!,
          currentSession.type == CallType.video,
          (candidate) {
            _sendSignalingEvent('ice_candidate', {
              'call_id': currentSession.callId,
              'target_id': currentSession.peerId,
              'candidate': jsonEncode({
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
              }),
            });
          },
        );

        _sendSignalingEvent('call_answer', {
          'call_id': currentSession.callId,
          'sdp': answer.sdp,
        });

        if (kDebugMode) debugPrint('[CallProvider] Answer sent for call ${currentSession.callId}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CallProvider] Error accepting call: $e');
      cleanup();
    }
  }

  /// Rejects the incoming call.
  void rejectCall() {
    final currentSession = state;
    if (currentSession == null) return;

    if (currentSession.status == CallStatus.ringing) {
      _sendSignalingEvent('call_reject', {
        'call_id': currentSession.callId,
        'reason': 'rejected',
      });
    }

    cleanup();
  }

  /// Ends the active call or cancels dialing.
  void endCall() {
    final currentSession = state;
    if (currentSession == null) return;

    if (currentSession.status == CallStatus.active && currentSession.callId.isNotEmpty) {
      if (currentSession.isGroup) {
        _sendSignalingEvent('group_call_leave', {
          'call_id': currentSession.callId,
        });
      } else {
        _sendSignalingEvent('call_end', {
          'call_id': currentSession.callId,
        });
      }
    }

    cleanup();
  }

  /// Handles call acceptance pushed from the server.
  Future<void> handleCallAccepted({
    required String callId,
    required String sdp,
  }) async {
    final currentSession = state;

    if (currentSession == null) {
      if (kDebugMode) debugPrint('[CallProvider] Received call_accepted but session was already cancelled. Hanging up.');
      _sendSignalingEvent('call_end', {
        'call_id': callId,
      });
      return;
    }

    if (currentSession.status != CallStatus.dialing) return;

    state = currentSession.copyWith(
      callId: callId,
      status: CallStatus.active,
      startTime: DateTime.now(),
    );

    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.setAnswer(currentSession.peerId, sdp);
    if (kDebugMode) debugPrint('[CallProvider] Peer connection established.');
  }

  /// Handles 1-1 to group call promotion signaling from the peer.
  Future<void> handleCallPromoted({
    required String callId,
    required String fromId,
  }) async {
    final currentSession = state;
    if (currentSession == null || currentSession.status != CallStatus.active) return;

    if (kDebugMode) debugPrint('[CallProvider] Call promoted to group by $fromId. New callId: $callId');

    // Close active 1-1 peer connection
    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.closePeerConnection(fromId);

    // Transition state
    state = currentSession.copyWith(
      callId: callId,
      peerId: '',
      peerName: 'Grup Araması',
      isGroup: true,
      activeParticipants: [],
    );

    // Join the promoted group call
    _sendSignalingEvent('group_call_join', {
      'call_id': callId,
      'group_id': '',
    });
  }

  /// Handles mesh signaling (group_call_offer) relayed from other group members.
  Future<void> handleGroupCallOffer({
    required String callId,
    required String fromId,
    required String sdp,
    required CallType type,
  }) async {
    final webrtc = ref.read(webrtcServiceProvider);

    if (state == null) {
      // Incoming group call invitation!
      final peerName = _resolvePeerName(fromId);
      state = CallSession(
        callId: callId,
        groupId: callId,
        peerId: '',
        peerName: 'Grup Araması',
        type: type,
        status: CallStatus.ringing,
        isGroup: true,
        activeParticipants: [fromId],
        peerNames: {fromId: peerName},
      );
      await webrtc.initializeRenderers();
      _incomingSdp = sdp;
      return;
    }

    if (state!.callId != callId) return;

    // Check if we already sent them an offer and are waiting for their answer
    // Standard mesh WebRTC checks signalingState
    final pc = webrtc.remoteRenderers.containsKey(fromId);
    if (pc) {
      await webrtc.setAnswer(fromId, sdp);
    } else {
      // Treat as incoming offer and accept it
      try {
        final answer = await webrtc.acceptOffer(
          fromId,
          sdp,
          state!.type == CallType.video,
          (candidate) {
            _sendSignalingEvent('ice_candidate', {
              'call_id': callId,
              'target_id': fromId,
              'candidate': jsonEncode({
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
              }),
            });
          },
        );

        _sendSignalingEvent('group_call_offer', {
          'group_id': state!.groupId ?? '',
          'call_type': state!.type == CallType.audio ? 'audio' : 'video',
          'sdp': answer.sdp,
          'target_id': fromId,
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[CallProvider] Error accepting mesh offer from $fromId: $e');
      }
    }
  }

  /// Handles group call member join/leave notifications.
  Future<void> handleGroupCallMember({
    required String callId,
    required String userId,
    required String action,
  }) async {
    final current = state;
    if (current == null || current.callId != callId) return;

    if (action == 'joined') {
      if (kDebugMode) debugPrint('[CallProvider] Peer $userId joined. Establishing mesh WebRTC offer.');
      
      final updatedNames = Map<String, String>.from(current.peerNames);
      if (!updatedNames.containsKey(userId)) {
        updatedNames[userId] = _resolvePeerName(userId);
      }
      state = current.copyWith(peerNames: updatedNames);

      // We are already in the call, so we initiate the offer to the new participant
      _inviteGroupMember(callId, userId, current.type);
    } else if (action == 'left') {
      if (kDebugMode) debugPrint('[CallProvider] Peer $userId left. Tearing down connection.');
      final webrtc = ref.read(webrtcServiceProvider);
      await webrtc.closePeerConnection(userId);
    }
  }

  /// Handles call rejection pushed from the server.
  void handleCallRejected({
    required String callId,
    required String reason,
  }) {
    final currentSession = state;
    if (currentSession == null) return;

    if (currentSession.status == CallStatus.dialing || currentSession.status == CallStatus.active) {
      cleanup();
    }
  }

  /// Handles call ended pushed from the server.
  void handleCallEnded({required String callId}) {
    final currentSession = state;
    if (currentSession == null) return;

    if (currentSession.callId == callId) {
      cleanup();
    }
  }

  /// Handles incoming remote ICE candidate.
  Future<void> handleIceCandidate({
    required String fromId,
    required String candidateJson,
  }) async {
    final currentSession = state;
    if (currentSession == null || currentSession.status == CallStatus.idle) return;

    try {
      final decoded = jsonDecode(candidateJson) as Map<String, dynamic>;
      final candidate = RTCIceCandidate(
        decoded['candidate'],
        decoded['sdpMid'],
        decoded['sdpMLineIndex'],
      );

      final webrtc = ref.read(webrtcServiceProvider);
      await webrtc.addCandidate(fromId, candidate);
    } catch (e) {
      if (kDebugMode) debugPrint('[CallProvider] Error adding remote candidate: $e');
    }
  }

  /// Handles connection errors (e.g. offline, busy, etc.) routed from WebSocket.
  void handleCallError(String errorMessage) {
    if (state != null) {
      if (kDebugMode) debugPrint('[CallProvider] Call failed with error: $errorMessage');
      cleanup();
    }
  }

  // ─── Controls ──────────────────────────────────────────────────────────────

  void toggleMute() {
    final currentSession = state;
    if (currentSession == null) return;

    final newVal = !currentSession.isMuted;
    ref.read(webrtcServiceProvider).toggleMute(newVal);
    state = currentSession.copyWith(isMuted: newVal);
  }

  void toggleCamera() {
    final currentSession = state;
    if (currentSession == null) return;

    final newVal = !currentSession.isCameraOff;
    ref.read(webrtcServiceProvider).toggleCamera(newVal);
    state = currentSession.copyWith(isCameraOff: newVal);
  }

  void toggleSpeaker() {
    final currentSession = state;
    if (currentSession == null) return;

    final newVal = !currentSession.isSpeakerOn;
    ref.read(webrtcServiceProvider).toggleSpeaker(newVal);
    state = currentSession.copyWith(isSpeakerOn: newVal);
  }

  void toggleMinimize() {
    final currentSession = state;
    if (currentSession == null) return;
    state = currentSession.copyWith(isMinimized: !currentSession.isMinimized);
  }

  // ─── Utility methods ───────────────────────────────────────────────────────

  void cleanup() {
    _incomingSdp = null;
    _saveCallLog();
    state = null;
    ref.read(webrtcServiceProvider).closeConnection();
  }

  void _saveCallLog() {
    final currentSession = state;
    if (currentSession != null && currentSession.callId.isNotEmpty) {
      final myUserId = ref.read(authProvider).userId ?? '';
      
      int durationSeconds = 0;
      if (currentSession.startTime != null) {
        durationSeconds = DateTime.now().difference(currentSession.startTime!).inSeconds;
      }
      
      String statusStr = "ended";
      if (currentSession.status == CallStatus.dialing) {
        statusStr = "missed";
      } else if (currentSession.status == CallStatus.ringing) {
        statusStr = "missed";
      } else if (currentSession.status == CallStatus.active) {
        statusStr = "connected";
      }
      
      final direction = currentSession.status == CallStatus.dialing ? "outgoing" : "incoming";
      
      final logPayload = {
        'call_id': currentSession.callId,
        'type': currentSession.type == CallType.audio ? 'audio' : 'video',
        'is_group': currentSession.isGroup,
        'duration': durationSeconds,
        'status': statusStr,
        'direction': direction,
      };
      
      final conversationId = currentSession.isGroup 
          ? (currentSession.groupId ?? currentSession.peerId)
          : currentSession.peerId;
          
      if (conversationId.isEmpty) return;
          
      final msgId = const Uuid().v4();
      
      final callLogMsg = MessageModel(
        id: msgId,
        conversationId: conversationId,
        senderId: myUserId,
        recipientId: conversationId,
        ciphertext: '',
        plaintext: jsonEncode(logPayload),
        msgType: 'call_log',
        createdAt: DateTime.now(),
      );
      
      final repo = ref.read(messageRepositoryProvider);
      repo.saveMessage(callLogMsg).then((_) {
        ref.read(conversationProvider.notifier).loadConversations();
        try {
          ref.read(chatProvider(conversationId).notifier).loadMessages();
        } catch (_) {}
      });
    }
  }

  void _sendSignalingEvent(String type, Map<String, dynamic> payload) {
    final ws = ref.read(webSocketProvider);
    if (ws != null && ws.isConnected) {
      ws.sendMessage(type, payload);
    } else {
      if (kDebugMode) debugPrint('[CallProvider] Failed to send WS event "$type": socket disconnected.');
    }
  }
}

final callProvider = NotifierProvider<CallNotifier, CallSession?>(CallNotifier.new);
