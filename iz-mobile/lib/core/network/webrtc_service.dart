import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebrtcService {
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  MediaStream? _localStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  // Legacy single remoteRenderer for 1-1 backwards compatibility
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  Function(String peerId, RTCVideoRenderer renderer)? onRemoteRendererAdded;
  Function(String peerId)? onRemoteRendererRemoved;

  bool _initialized = false;

  Future<void> initializeRenderers() async {
    if (_initialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _initialized = true;
  }

  Future<void> dispose() async {
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    
    for (final renderer in remoteRenderers.values) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    remoteRenderers.clear();

    await closeConnection();
    _initialized = false;
  }

  Future<void> closeConnection() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    final peerIds = List<String>.from(_peerConnections.keys);
    for (final peerId in peerIds) {
      await closePeerConnection(peerId);
    }
    _peerConnections.clear();
    _remoteStreams.clear();
  }

  Future<void> closePeerConnection(String peerId) async {
    final stream = _remoteStreams.remove(peerId);
    if (stream != null) {
      stream.getTracks().forEach((track) => track.stop());
      await stream.dispose();
    }

    if (remoteRenderer.srcObject == stream) {
      remoteRenderer.srcObject = null;
    }

    final renderer = remoteRenderers.remove(peerId);
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
      onRemoteRendererRemoved?.call(peerId);
    }

    final pc = _peerConnections.remove(peerId);
    if (pc != null) {
      await pc.close();
      await pc.dispose();
    }
  }

  Future<RTCSessionDescription> createOffer(
    String peerId,
    bool isVideo,
    Function(RTCIceCandidate) onIceCandidate,
  ) async {
    // 1. Get user media if not already captured
    if (_localStream == null) {
      final mediaConstraints = {
        'audio': true,
        'video': isVideo ? {'facingMode': 'user'} : false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
    }

    await closePeerConnection(peerId);

    // 2. Create peer connection
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };
    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    final pc = await createPeerConnection(configuration, constraints);
    _peerConnections[peerId] = pc;

    // 3. Add local stream
    await pc.addStream(_localStream!);

    // 4. Attach callbacks
    pc.onIceCandidate = (candidate) {
      onIceCandidate(candidate);
    };

    pc.onAddStream = (stream) {
      _handleRemoteStream(peerId, stream);
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _handleRemoteStream(peerId, event.streams[0]);
      }
    };

    // 5. Create offer
    final offerConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': isVideo,
      },
      'optional': [],
    };
    RTCSessionDescription offer = await pc.createOffer(offerConstraints);
    await pc.setLocalDescription(offer);

    return offer;
  }

  Future<RTCSessionDescription> acceptOffer(
    String peerId,
    String sdp,
    bool isVideo,
    Function(RTCIceCandidate) onIceCandidate,
  ) async {
    // 1. Get user media if not already captured
    if (_localStream == null) {
      final mediaConstraints = {
        'audio': true,
        'video': isVideo ? {'facingMode': 'user'} : false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
    }

    await closePeerConnection(peerId);

    // 2. Create peer connection
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };
    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    final pc = await createPeerConnection(configuration, constraints);
    _peerConnections[peerId] = pc;

    // 3. Add local stream
    await pc.addStream(_localStream!);

    // 4. Attach callbacks
    pc.onIceCandidate = (candidate) {
      onIceCandidate(candidate);
    };

    pc.onAddStream = (stream) {
      _handleRemoteStream(peerId, stream);
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _handleRemoteStream(peerId, event.streams[0]);
      }
    };

    // 5. Set Remote Description
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

    // 6. Create Answer
    final answerConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': isVideo,
      },
      'optional': [],
    };
    RTCSessionDescription answer = await pc.createAnswer(answerConstraints);
    await pc.setLocalDescription(answer);

    return answer;
  }

  Future<void> setAnswer(String peerId, String sdp) async {
    final pc = _peerConnections[peerId];
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> addCandidate(String peerId, RTCIceCandidate candidate) async {
    final pc = _peerConnections[peerId];
    if (pc == null) return;
    await pc.addCandidate(candidate);
  }

  void _handleRemoteStream(String peerId, MediaStream stream) async {
    _remoteStreams[peerId] = stream;

    // Setup legacy single remoteRenderer for 1-1 backwards compatibility
    remoteRenderer.srcObject ??= stream;

    var renderer = remoteRenderers[peerId];
    if (renderer == null) {
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      remoteRenderers[peerId] = renderer;
    }

    renderer.srcObject = stream;
    onRemoteRendererAdded?.call(peerId, renderer);
  }

  void toggleMute(bool isMuted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !isMuted;
    });
  }

  void toggleCamera(bool isCameraOff) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !isCameraOff;
    });
  }

  void toggleSpeaker(bool isSpeakerOn) {
    Helper.setSpeakerphoneOn(isSpeakerOn);
  }
}
