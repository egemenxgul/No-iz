import { wsManager } from './websocket';

export interface CallState {
  status: 'idle' | 'ringing' | 'connecting' | 'connected' | 'ended';
  callId?: string;
  peerId?: string; // Original caller/callee or groupId in group calls
  isVideo?: boolean;
  isIncoming?: boolean;
  callerName?: string;
  isGroupCall?: boolean;
  groupId?: string;
  remoteStreams: Map<string, MediaStream>; // Map of participant IDs to their MediaStream
  participants: string[]; // List of active participant IDs
}

export interface WebRTCEvents {
  onStateChange?: (state: CallState) => void;
  onLocalStream?: (stream: MediaStream | null) => void;
  onRemoteStreamsChange?: (streams: Map<string, MediaStream>) => void;
  onError?: (err: string) => void;
}

const STUN_SERVERS = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
  ],
};

class WebRTCManager {
  private pcs: Map<string, RTCPeerConnection> = new Map();
  private localStream: MediaStream | null = null;
  private state: CallState = { status: 'idle', remoteStreams: new Map(), participants: [] };
  public events: WebRTCEvents = {};
  
  // To keep track of incoming offers that haven't been processed yet
  private pendingOfferSdp: string | null = null;
  private incomingGroupCallSdpMap: Map<string, string> = new Map(); // fromId -> sdp

  constructor() {
    this.setupListeners();
  }

  private setState(newState: Partial<CallState>) {
    this.state = { ...this.state, ...newState };
    if (this.state.status === 'ended') {
      setTimeout(() => {
        if (this.state.status === 'ended') {
          this.state = { status: 'idle', remoteStreams: new Map(), participants: [] };
          this.events.onStateChange?.(this.state);
        }
      }, 3000);
    }
    this.events.onStateChange?.(this.state);
  }

  private setupListeners() {
    // 1-1 Call Events
    wsManager.on('call_offer', async (payload: any) => {
      if (this.state.status !== 'idle') {
        wsManager.send('call_reject', { call_id: payload.call_id, reason: 'busy' });
        return;
      }
      this.pendingOfferSdp = payload.sdp;
      this.setState({
        status: 'ringing',
        callId: payload.call_id,
        peerId: payload.caller_id,
        isVideo: payload.call_type === 'video',
        isIncoming: true,
        callerName: payload.caller_name || 'Bilinmeyen Arayan',
        isGroupCall: false,
      });
    });

    wsManager.on('call_answer', async (payload: any) => {
      if (this.state.callId !== payload.call_id) return;
      try {
        // Find the PC for 1-1
        const pc = this.pcs.get(this.state.peerId!);
        if (pc) {
          await pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: payload.sdp }));
          this.setState({ status: 'connected' });
        }
      } catch (err) {
        console.error('Failed to set remote answer', err);
      }
    });

    wsManager.on('ice_candidate', async (payload: any) => {
      if (this.state.callId !== payload.call_id && this.state.groupId !== payload.call_id) return;
      try {
        const candidate = JSON.parse(payload.candidate);
        const targetId = payload.caller_id || payload.target_id || this.state.peerId;
        const pc = this.pcs.get(targetId);
        if (pc) {
          await pc.addIceCandidate(new RTCIceCandidate(candidate));
        }
      } catch (e) {
        console.error('Failed to add ICE candidate', e);
      }
    });

    wsManager.on('call_reject', (payload: any) => {
      if (this.state.callId === payload.call_id) {
        this.cleanup('Reddedildi');
      }
    });

    wsManager.on('call_end', (payload: any) => {
      if (this.state.callId === payload.call_id) {
        this.cleanup();
      }
    });

    // Group Call Events
    wsManager.on('group_call_offer', async (payload: any) => {
      const fromId = payload.caller_id || payload.target_id; // from whoever sent it, wait caller_id or target_id? backend routes target_id.
      // Usually the one sending the offer is the caller. In group_call_offer, target_id is where it's sent.
      // We need to know who sent it. Let's assume payload.caller_id is the sender.
      const senderId = payload.caller_id || payload.user_id || payload.from_id; // Check payload structure if possible. Usually the backend appends caller_id.
      const sdp = payload.sdp;
      const groupId = payload.group_id;

      if (this.state.status === 'idle') {
        // Incoming group call invitation
        if (senderId) this.incomingGroupCallSdpMap.set(senderId, sdp);
        this.setState({
          status: 'ringing',
          callId: groupId, // Using groupId as callId for groups
          groupId: groupId,
          isVideo: payload.call_type === 'video',
          isIncoming: true,
          callerName: 'Grup Araması',
          isGroupCall: true,
          participants: senderId ? [senderId] : [],
        });
        return;
      }

      if (this.state.groupId !== groupId || !senderId) return;

      // Check if we already have a PC (mesh standard check)
      let pc = this.pcs.get(senderId);
      if (pc) {
        await pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: sdp }));
      } else {
        // We need to accept this mesh offer
        try {
          pc = this.createPeerConnection(senderId, groupId);
          await pc.setRemoteDescription(new RTCSessionDescription({ type: 'offer', sdp: sdp }));
          const answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);

          wsManager.send('group_call_offer', {
            group_id: groupId,
            call_type: this.state.isVideo ? 'video' : 'audio',
            sdp: answer.sdp,
            target_id: senderId,
          });
          
          if (!this.state.participants.includes(senderId)) {
            this.setState({ participants: [...this.state.participants, senderId] });
          }
        } catch (e) {
          console.error('Error accepting mesh offer', e);
        }
      }
    });

    wsManager.on('group_call_member', async (payload: any) => {
      if (this.state.groupId !== payload.call_id && this.state.callId !== payload.call_id) return;
      const userId = payload.user_id;
      const action = payload.action;

      if (action === 'joined') {
        if (!this.state.participants.includes(userId)) {
          this.setState({ participants: [...this.state.participants, userId] });
          // Initiate mesh offer to the new member
          try {
            const pc = this.createPeerConnection(userId, this.state.groupId!);
            const offer = await pc.createOffer();
            await pc.setLocalDescription(offer);
            wsManager.send('group_call_offer', {
              group_id: this.state.groupId,
              call_type: this.state.isVideo ? 'video' : 'audio',
              sdp: offer.sdp,
              target_id: userId,
            });
          } catch (e) {
            console.error('Error sending mesh offer', e);
          }
        }
      } else if (action === 'left') {
        this.closePeerConnection(userId);
        this.setState({
          participants: this.state.participants.filter(p => p !== userId)
        });
      }
    });
  }

  private async getMedia(video: boolean): Promise<MediaStream> {
    if (this.localStream) return this.localStream;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video });
      this.localStream = stream;
      this.events.onLocalStream?.(stream);
      return stream;
    } catch (err: any) {
      throw new Error('Kamera/Mikrofon izni alınamadı: ' + err.message);
    }
  }

  private createPeerConnection(targetId: string, callId: string): RTCPeerConnection {
    if (this.pcs.has(targetId)) return this.pcs.get(targetId)!;

    const pc = new RTCPeerConnection(STUN_SERVERS);
    this.pcs.set(targetId, pc);
    
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        wsManager.send('ice_candidate', {
          call_id: callId,
          target_id: targetId,
          candidate: JSON.stringify(event.candidate.toJSON()),
        });
      }
    };

    pc.ontrack = (event) => {
      if (event.streams && event.streams[0]) {
        const stream = event.streams[0];
        const updatedMap = new Map(this.state.remoteStreams);
        updatedMap.set(targetId, stream);
        this.state.remoteStreams = updatedMap;
        this.events.onRemoteStreamsChange?.(updatedMap);
        // Also trigger state change so UI reacts to remote streams
        this.setState({ remoteStreams: updatedMap });
      }
    };

    if (this.localStream) {
      this.localStream.getTracks().forEach(track => {
        pc.addTrack(track, this.localStream!);
      });
    }

    return pc;
  }

  private closePeerConnection(targetId: string) {
    const pc = this.pcs.get(targetId);
    if (pc) {
      pc.close();
      this.pcs.delete(targetId);
    }
    const updatedMap = new Map(this.state.remoteStreams);
    updatedMap.delete(targetId);
    this.state.remoteStreams = updatedMap;
    this.events.onRemoteStreamsChange?.(updatedMap);
    this.setState({ remoteStreams: updatedMap });
  }

  // 1-1 Call
  async startCall(calleeId: string, isVideo: boolean = false) {
    if (this.state.status !== 'idle') return;
    try {
      this.setState({ status: 'connecting', isIncoming: false, peerId: calleeId, isVideo, isGroupCall: false });
      
      await this.getMedia(isVideo);
      const tempCallId = crypto.randomUUID(); 
      this.setState({ callId: tempCallId });

      const pc = this.createPeerConnection(calleeId, tempCallId);
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      wsManager.send('call_offer', {
        callee_id: calleeId,
        call_type: isVideo ? 'video' : 'audio',
        sdp: offer.sdp,
        call_id: tempCallId
      });

    } catch (err: any) {
      this.cleanup(err.message);
    }
  }

  // Group Call
  async startGroupCall(groupId: string, participantIds: string[], isVideo: boolean = false) {
    if (this.state.status !== 'idle') return;
    try {
      this.setState({ 
        status: 'connecting', 
        isIncoming: false, 
        groupId: groupId, 
        callId: groupId,
        isVideo, 
        isGroupCall: true,
        participants: participantIds
      });
      
      await this.getMedia(isVideo);
      
      wsManager.send('group_call_join', {
        call_id: groupId,
        group_id: groupId,
      });

      for (const targetId of participantIds) {
        try {
          const pc = this.createPeerConnection(targetId, groupId);
          const offer = await pc.createOffer();
          await pc.setLocalDescription(offer);

          wsManager.send('group_call_offer', {
            group_id: groupId,
            call_type: isVideo ? 'video' : 'audio',
            sdp: offer.sdp,
            target_id: targetId,
          });
        } catch (e) {
          console.error('Error offering to participant', targetId, e);
        }
      }
    } catch (err: any) {
      this.cleanup(err.message);
    }
  }

  async answerCall() {
    if (this.state.status !== 'ringing' || !this.state.isIncoming) return;
    
    try {
      this.setState({ status: 'connecting' });
      await this.getMedia(!!this.state.isVideo);

      if (this.state.isGroupCall && this.state.groupId) {
        // Group call answer
        wsManager.send('group_call_join', {
          call_id: this.state.groupId,
          group_id: this.state.groupId,
        });

        // Answer pending offers from callers
        for (const [fromId, sdp] of this.incomingGroupCallSdpMap.entries()) {
          const pc = this.createPeerConnection(fromId, this.state.groupId);
          await pc.setRemoteDescription(new RTCSessionDescription({ type: 'offer', sdp }));
          const answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);

          wsManager.send('group_call_offer', {
            group_id: this.state.groupId,
            call_type: this.state.isVideo ? 'video' : 'audio',
            sdp: answer.sdp,
            target_id: fromId,
          });
        }
        this.incomingGroupCallSdpMap.clear();
        this.setState({ status: 'connected' });

      } else {
        // 1-1 call answer
        const { callId, peerId } = this.state;
        if (!callId || !peerId) return;

        const pc = this.createPeerConnection(peerId, callId);
        if (this.pendingOfferSdp) {
          await pc.setRemoteDescription(new RTCSessionDescription({ type: 'offer', sdp: this.pendingOfferSdp }));
          const answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);

          wsManager.send('call_answer', {
            call_id: callId,
            sdp: answer.sdp,
          });
          this.setState({ status: 'connected' });
        }
      }
    } catch (err: any) {
      this.cleanup(err.message);
    }
  }

  rejectCall() {
    if (!this.state.isGroupCall && this.state.callId) {
      wsManager.send('call_reject', { call_id: this.state.callId });
    }
    // For group calls, there is no explicit reject in the protocol, just don't join
    this.cleanup();
  }

  endCall() {
    if (this.state.isGroupCall && this.state.groupId) {
      wsManager.send('group_call_leave', {
        call_id: this.state.groupId,
      });
    } else if (this.state.callId) {
      wsManager.send('call_end', { call_id: this.state.callId });
    }
    this.cleanup();
  }

  toggleVideo(enabled: boolean) {
    if (this.localStream) {
      this.localStream.getVideoTracks().forEach(track => {
        track.enabled = enabled;
      });
    }
  }

  toggleAudio(enabled: boolean) {
    if (this.localStream) {
      this.localStream.getAudioTracks().forEach(track => {
        track.enabled = enabled;
      });
    }
  }

  private cleanup(errorMsg?: string) {
    if (errorMsg) {
      this.events.onError?.(errorMsg);
    }
    
    // Close all peer connections
    for (const [id, pc] of this.pcs.entries()) {
      pc.close();
    }
    this.pcs.clear();

    this.localStream?.getTracks().forEach(t => t.stop());
    this.localStream = null;
    const oldRemoteStreams = this.state.remoteStreams;
    this.state.remoteStreams.clear();
    this.events.onLocalStream?.(null);
    this.events.onRemoteStreamsChange?.(new Map());
    this.pendingOfferSdp = null;
    this.incomingGroupCallSdpMap.clear();
    
    this.setState({ status: 'ended', participants: [], remoteStreams: new Map() });
  }
}

export const webrtcManager = new WebRTCManager();
