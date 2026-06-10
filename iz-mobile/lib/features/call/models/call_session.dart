enum CallType { audio, video }

enum CallStatus { idle, dialing, ringing, active, ended }

class CallSession {
  final String callId;
  final String peerId;
  final String peerName;
  final CallType type;
  final CallStatus status;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isMinimized;
  final DateTime? startTime;

  // Group Call specific fields
  final bool isGroup;
  final String? groupId;
  final List<String> activeParticipants;
  final Map<String, String> peerNames;

  CallSession({
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.type,
    required this.status,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = false,
    this.isMinimized = false,
    this.isGroup = false,
    this.groupId,
    this.activeParticipants = const [],
    this.peerNames = const {},
    this.startTime,
  });

  CallSession copyWith({
    String? callId,
    String? peerId,
    String? peerName,
    CallType? type,
    CallStatus? status,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    bool? isMinimized,
    bool? isGroup,
    String? groupId,
    List<String>? activeParticipants,
    Map<String, String>? peerNames,
    DateTime? startTime,
  }) {
    return CallSession(
      callId: callId ?? this.callId,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      type: type ?? this.type,
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isMinimized: isMinimized ?? this.isMinimized,
      isGroup: isGroup ?? this.isGroup,
      groupId: groupId ?? this.groupId,
      activeParticipants: activeParticipants ?? this.activeParticipants,
      peerNames: peerNames ?? this.peerNames,
      startTime: startTime ?? this.startTime,
    );
  }
}
