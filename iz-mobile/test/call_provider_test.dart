
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:iz_mobile/core/network/webrtc_service.dart';
import 'package:iz_mobile/core/network/websocket_provider.dart';
import 'package:iz_mobile/core/network/websocket_service.dart';
import 'package:iz_mobile/features/call/models/call_session.dart';
import 'package:iz_mobile/features/call/providers/call_provider.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/messages/providers/message_model.dart';
import 'package:iz_mobile/features/messages/providers/message_repository.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';


class FakeWebrtcService extends Fake implements WebrtcService {
  bool initialized = false;
  bool closed = false;
  String? remoteSdp;
  bool isVideoCall = false;
  bool isMuted = false;
  bool isCameraOff = false;
  bool isSpeakerOn = false;

  @override
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  @override
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  @override
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  @override
  Function(String peerId, RTCVideoRenderer renderer)? onRemoteRendererAdded;
  @override
  Function(String peerId)? onRemoteRendererRemoved;

  @override
  Future<void> initializeRenderers() async {
    initialized = true;
  }

  @override
  Future<void> dispose() async {
    initialized = false;
  }

  @override
  Future<void> closeConnection() async {
    closed = true;
  }

  @override
  Future<void> closePeerConnection(String peerId) async {
    remoteRenderers.remove(peerId);
  }

  @override
  Future<RTCSessionDescription> createOffer(
    String peerId,
    bool isVideo,
    Function(RTCIceCandidate) onIceCandidate,
  ) async {
    isVideoCall = isVideo;
    return RTCSessionDescription('dummy-sdp-offer', 'offer');
  }

  @override
  Future<RTCSessionDescription> acceptOffer(
    String peerId,
    String sdp,
    bool isVideo,
    Function(RTCIceCandidate) onIceCandidate,
  ) async {
    remoteSdp = sdp;
    isVideoCall = isVideo;
    return RTCSessionDescription('dummy-sdp-answer', 'answer');
  }

  @override
  Future<void> setAnswer(String peerId, String sdp) async {
    remoteSdp = sdp;
  }

  @override
  Future<void> addCandidate(String peerId, RTCIceCandidate candidate) async {
    // dummy
  }

  @override
  void toggleMute(bool muted) {
    isMuted = muted;
  }

  @override
  void toggleCamera(bool cameraOff) {
    isCameraOff = cameraOff;
  }

  @override
  void toggleSpeaker(bool speakerOn) {
    isSpeakerOn = speakerOn;
  }
}

class FakeWebSocketService extends Fake implements WebSocketService {
  final List<Map<String, dynamic>> sentMessages = [];
  bool connected = true;

  @override
  bool get isConnected => connected;

  @override
  void sendMessage(String type, Map<String, dynamic> payload) {
    sentMessages.add({
      'type': type,
      'payload': payload,
    });
  }
}

class FakeConversationNotifier extends ConversationNotifier {
  @override
  List<ConversationModel> build() {
    return [
      ConversationModel(
        id: 'conv-1',
        otherUserId: 'peer-user-123',
        otherUsername: 'peer_user',
        otherDisplayName: 'Ahmet Yılmaz',
      ),
    ];
  }

  @override
  Future<void> loadConversations() async {}
}

class FakeMessageRepository extends Fake implements MessageRepository {
  @override
  Future<void> saveMessage(MessageModel message) async {}
  
  @override
  Future<List<MessageModel>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    return [];
  }
}

class FakeAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  @override
  AuthState build() => AuthState(userId: 'test_user');
  
  @override
  Future<void> login(String id, String password) async {}
  
  @override
  Future<void> logout() async {}

  @override
  Future<void> login2FA(String code) async {}

  @override
  Future<void> loginWithApple() async {}

  @override
  void setSession({required bool isAuthenticated, String? userId}) {}
}

void main() {
  group('CallProvider Unit Tests', () {
    late ProviderContainer container;
    late FakeWebrtcService fakeWebrtc;
    late FakeWebSocketService fakeWs;

    setUp(() {
      fakeWebrtc = FakeWebrtcService();
      fakeWs = FakeWebSocketService();

      container = ProviderContainer(
        overrides: [
          webrtcServiceProvider.overrideWithValue(fakeWebrtc),
          webSocketProvider.overrideWithValue(fakeWs),
          conversationProvider.overrideWith(FakeConversationNotifier.new),
          messageRepositoryProvider.overrideWithValue(FakeMessageRepository()),
          authProvider.overrideWith(FakeAuthNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial call state should be null (idle)', () {
      final callState = container.read(callProvider);
      expect(callState, isNull);
    });

    test('startCall transitions to dialing and creates a WebRTC offer', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.startCall(
        peerId: 'peer-user-123',
        peerName: 'Ahmet Yılmaz',
        type: CallType.video,
      );

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.status, CallStatus.dialing);
      expect(state.peerId, 'peer-user-123');
      expect(state.peerName, 'Ahmet Yılmaz');
      expect(state.type, CallType.video);

      expect(fakeWebrtc.initialized, isTrue);
      expect(fakeWebrtc.isVideoCall, isTrue);

      // Verify that call_offer was sent over WS
      expect(fakeWs.sentMessages.length, 1);
      expect(fakeWs.sentMessages.first['type'], 'call_offer');
      expect(fakeWs.sentMessages.first['payload']['callee_id'], 'peer-user-123');
      expect(fakeWs.sentMessages.first['payload']['call_type'], 'video');
      expect(fakeWs.sentMessages.first['payload']['sdp'], 'dummy-sdp-offer');
    });

    test('receiveOffer transitions to ringing and resolves name using conversationProvider', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.receiveOffer(
        callId: 'call-uuid-999',
        callerId: 'peer-user-123',
        sdp: 'incoming-sdp-offer',
        type: CallType.audio,
      );

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.status, CallStatus.ringing);
      expect(state.callId, 'call-uuid-999');
      expect(state.peerId, 'peer-user-123');
      expect(state.peerName, 'Ahmet Yılmaz'); // Resolved from conversationProvider!
      expect(state.type, CallType.audio);

      expect(fakeWebrtc.initialized, isTrue);
    });

    test('receiveOffer defaults peer name if not found in conversationProvider', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.receiveOffer(
        callId: 'call-uuid-999',
        callerId: 'unknown-user',
        sdp: 'incoming-sdp-offer',
        type: CallType.audio,
      );

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.peerName, 'Kullanıcı (unknown-user)');
    });

    test('acceptCall transitions from ringing to active and sends call_answer', () async {
      final notifier = container.read(callProvider.notifier);

      // 1. Receive offer to set state to ringing
      await notifier.receiveOffer(
        callId: 'call-uuid-999',
        callerId: 'peer-user-123',
        sdp: 'incoming-sdp-offer',
        type: CallType.audio,
      );

      // 2. Accept call
      await notifier.acceptCall();

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.status, CallStatus.active);
      expect(fakeWebrtc.remoteSdp, 'incoming-sdp-offer');

      // Verify that call_answer was sent over WS
      final answerMessage = fakeWs.sentMessages.firstWhere((m) => m['type'] == 'call_answer');
      expect(answerMessage['payload']['call_id'], 'call-uuid-999');
      expect(answerMessage['payload']['sdp'], 'dummy-sdp-answer');
    });

    test('rejectCall sends call_reject and transitions to null', () async {
      final notifier = container.read(callProvider.notifier);

      // 1. Receive offer
      await notifier.receiveOffer(
        callId: 'call-uuid-999',
        callerId: 'peer-user-123',
        sdp: 'incoming-sdp-offer',
        type: CallType.audio,
      );

      // 2. Reject call
      notifier.rejectCall();

      final state = container.read(callProvider);
      expect(state, isNull);

      // Verify call_reject WS message sent
      expect(fakeWs.sentMessages.length, 1);
      expect(fakeWs.sentMessages.first['type'], 'call_reject');
      expect(fakeWs.sentMessages.first['payload']['call_id'], 'call-uuid-999');
      expect(fakeWs.sentMessages.first['payload']['reason'], 'rejected');
    });

    test('endCall on active session sends call_end and cleans up', () async {
      final notifier = container.read(callProvider.notifier);

      // Get into active state
      await notifier.receiveOffer(
        callId: 'call-uuid-999',
        callerId: 'peer-user-123',
        sdp: 'incoming-sdp-offer',
        type: CallType.audio,
      );
      await notifier.acceptCall();

      // Reset WS message tracker to isolate call_end
      fakeWs.sentMessages.clear();

      // End call
      notifier.endCall();

      final state = container.read(callProvider);
      expect(state, isNull);
      expect(fakeWebrtc.closed, isTrue);

      // Verify call_end WS message sent
      expect(fakeWs.sentMessages.length, 1);
      expect(fakeWs.sentMessages.first['type'], 'call_end');
      expect(fakeWs.sentMessages.first['payload']['call_id'], 'call-uuid-999');
    });

    test('SMART FALLBACK: handleCallAccepted when caller has cancelled sends call_end immediately', () async {
      final notifier = container.read(callProvider.notifier);

      // 1. Start call
      await notifier.startCall(
        peerId: 'peer-user-123',
        peerName: 'Ahmet Yılmaz',
        type: CallType.audio,
      );

      // 2. Caller cancels dialing (state becomes null)
      notifier.endCall();
      expect(container.read(callProvider), isNull);

      // Clear WS message tracker
      fakeWs.sentMessages.clear();

      // 3. Backend late-delivers a call_accepted event
      await notifier.handleCallAccepted(
        callId: 'call-uuid-resolved-by-db',
        sdp: 'belated-sdp-answer',
      );

      // State remains null
      expect(container.read(callProvider), isNull);

      // WS should have immediately dispatched call_end for call-uuid-resolved-by-db
      expect(fakeWs.sentMessages.length, 1);
      expect(fakeWs.sentMessages.first['type'], 'call_end');
      expect(fakeWs.sentMessages.first['payload']['call_id'], 'call-uuid-resolved-by-db');
    });

    test('handleCallAccepted transitions to active and sets answer under normal flow', () async {
      final notifier = container.read(callProvider.notifier);

      // 1. Start call
      await notifier.startCall(
        peerId: 'peer-user-123',
        peerName: 'Ahmet Yılmaz',
        type: CallType.audio,
      );

      // 2. Receive acceptance normally
      await notifier.handleCallAccepted(
        callId: 'call-uuid-established',
        sdp: 'valid-sdp-answer',
      );

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.status, CallStatus.active);
      expect(state.callId, 'call-uuid-established');
      expect(fakeWebrtc.remoteSdp, 'valid-sdp-answer');
    });

    test('handleCallRejected cleans up the call session', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.startCall(
        peerId: 'peer-user-123',
        peerName: 'Ahmet Yılmaz',
        type: CallType.audio,
      );

      notifier.handleCallRejected(
        callId: '',
        reason: 'callee is busy',
      );

      expect(container.read(callProvider), isNull);
      expect(fakeWebrtc.closed, isTrue);
    });

    test('handleCallEnded cleans up session if call IDs match', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.receiveOffer(
        callId: 'call-uuid-999',
        callerId: 'peer-user-123',
        sdp: 'offer',
        type: CallType.audio,
      );
      await notifier.acceptCall();

      // Ending a different call ID does not close our call
      notifier.handleCallEnded(callId: 'different-call-id');
      expect(container.read(callProvider), isNotNull);

      // Ending our call ID closes it
      notifier.handleCallEnded(callId: 'call-uuid-999');
      expect(container.read(callProvider), isNull);
      expect(fakeWebrtc.closed, isTrue);
    });

    test('handleCallError cleans up session when active', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.startCall(
        peerId: 'peer-user-123',
        peerName: 'Ahmet Yılmaz',
        type: CallType.audio,
      );

      notifier.handleCallError('some signal error occurred');
      expect(container.read(callProvider), isNull);
    });

    test('toggleMute, toggleCamera, and toggleSpeaker modify session states correctly', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.startCall(
        peerId: 'peer-user-123',
        peerName: 'Ahmet Yılmaz',
        type: CallType.video,
      );

      // Mute toggle
      expect(container.read(callProvider)!.isMuted, isFalse);
      notifier.toggleMute();
      expect(container.read(callProvider)!.isMuted, isTrue);
      expect(fakeWebrtc.isMuted, isTrue);

      // Camera toggle
      expect(container.read(callProvider)!.isCameraOff, isFalse);
      notifier.toggleCamera();
      expect(container.read(callProvider)!.isCameraOff, isTrue);
      expect(fakeWebrtc.isCameraOff, isTrue);

      // Speaker toggle
      expect(container.read(callProvider)!.isSpeakerOn, isFalse);
      notifier.toggleSpeaker();
      expect(container.read(callProvider)!.isSpeakerOn, isTrue);
      expect(fakeWebrtc.isSpeakerOn, isTrue);

      // Minimize toggle
      expect(container.read(callProvider)!.isMinimized, isFalse);
      notifier.toggleMinimize();
      expect(container.read(callProvider)!.isMinimized, isTrue);
    });

    test('startGroupCall sets state to active group call and sends join and offers', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.startGroupCall(
        groupId: 'group-uuid-111',
        members: ['peer-user-123', 'another-peer'],
        type: CallType.video,
      );

      await Future.delayed(Duration.zero);

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.isGroup, isTrue);
      expect(state.groupId, 'group-uuid-111');
      expect(state.status, CallStatus.active);
      expect(state.peerNames['peer-user-123'], 'Ahmet Yılmaz');

      // Verify that group_call_join and group_call_offers are sent
      final joinMsg = fakeWs.sentMessages.firstWhere((m) => m['type'] == 'group_call_join');
      expect(joinMsg['payload']['group_id'], 'group-uuid-111');

      final offerMsgs = fakeWs.sentMessages.where((m) => m['type'] == 'group_call_offer').toList();
      expect(offerMsgs.length, 2);
    });

    test('inviteParticipant promotes 1-1 active call to group call', () async {
      final notifier = container.read(callProvider.notifier);

      // Start a 1-1 active call
      await notifier.receiveOffer(
        callId: '1-1-call-id',
        callerId: 'peer-user-123',
        sdp: 'sdp-offer',
        type: CallType.audio,
      );
      await notifier.acceptCall();

      // Clear ws tracker
      fakeWs.sentMessages.clear();

      // Invite another participant
      await notifier.inviteParticipant('another-peer');

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.isGroup, isTrue);
      expect(state.groupId, isNotEmpty);
      expect(state.groupId, state.callId); // Promoted call sets groupId to callId
      expect(state.peerNames['peer-user-123'], 'Ahmet Yılmaz');
      expect(state.peerNames['another-peer'], 'Kullanıcı (another-peer)');

      // Verify call_promote and group_call_join were sent
      final promoteMsg = fakeWs.sentMessages.firstWhere((m) => m['type'] == 'call_promote');
      expect(promoteMsg['payload']['target_id'], 'peer-user-123');

      final joinMsg = fakeWs.sentMessages.firstWhere((m) => m['type'] == 'group_call_join');
      expect(joinMsg['payload']['call_id'], state.callId);
    });

    test('handleGroupCallOffer handles incoming group call offer when idle', () async {
      final notifier = container.read(callProvider.notifier);

      await notifier.handleGroupCallOffer(
        callId: 'group-call-uuid-222',
        fromId: 'peer-user-123',
        sdp: 'sdp-offer',
        type: CallType.video,
      );

      final state = container.read(callProvider);
      expect(state, isNotNull);
      expect(state!.status, CallStatus.ringing);
      expect(state.isGroup, isTrue);
      expect(state.groupId, 'group-call-uuid-222');
      expect(state.peerNames['peer-user-123'], 'Ahmet Yılmaz');
    });

    test('handleGroupCallMember updates participant list', () async {
      final notifier = container.read(callProvider.notifier);

      // Start group call
      await notifier.startGroupCall(
        groupId: 'group-uuid-111',
        members: ['peer-user-123'],
        type: CallType.audio,
      );

      // Simulate a member joining
      await notifier.handleGroupCallMember(
        callId: container.read(callProvider)!.callId,
        userId: 'another-peer',
        action: 'joined',
      );

      expect(container.read(callProvider)!.peerNames.containsKey('another-peer'), isTrue);
    });
  });
}
