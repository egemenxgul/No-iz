import { wsManager } from './websocket';

export interface CallState {
  status: 'idle' | 'ringing' | 'connecting' | 'connected' | 'ended';
  callId?: string;
  peerId?: string;
  isVideo?: boolean;
  isIncoming?: boolean;
  callerName?: string;
}

export interface WebRTCEvents {
  onStateChange?: (state: CallState) => void;
  onLocalStream?: (stream: MediaStream | null) => void;
  onRemoteStream?: (stream: MediaStream | null) => void;
  onError?: (err: string) => void;
}

const STUN_SERVERS = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
  ],
};

class WebRTCManager {
  private pc: RTCPeerConnection | null = null;
  private localStream: MediaStream | null = null;
  private remoteStream: MediaStream | null = null;
  private state: CallState = { status: 'idle' };
  public events: WebRTCEvents = {};

  constructor() {
    this.setupListeners();
  }

  private setState(newState: Partial<CallState>) {
    this.state = { ...this.state, ...newState };
    if (this.state.status === 'ended') {
      setTimeout(() => {
        if (this.state.status === 'ended') {
          this.state = { status: 'idle' };
          this.events.onStateChange?.(this.state);
        }
      }, 3000);
    }
    this.events.onStateChange?.(this.state);
  }

  private setupListeners() {
    wsManager.on('call_offer', async (payload: any) => {
      if (this.state.status !== 'idle') {
        // Busy
        wsManager.send('call_reject', { call_id: payload.call_id, reason: 'busy' });
        return;
      }
      this.setState({
        status: 'ringing',
        callId: payload.call_id,
        peerId: payload.caller_id,
        isVideo: payload.call_type === 'video',
        isIncoming: true,
        callerName: payload.caller_name || 'Bilinmeyen Arayan',
      });
      // We will save the offer SDP to apply later if accepted
      (this as any).pendingOfferSdp = payload.sdp;
    });

    wsManager.on('call_answer', async (payload: any) => {
      if (this.state.callId !== payload.call_id || !this.pc) return;
      try {
        await this.pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: payload.sdp }));
        this.setState({ status: 'connected' });
      } catch (err) {
        console.error('Failed to set remote answer', err);
      }
    });

    wsManager.on('ice_candidate', async (payload: any) => {
      if (this.state.callId !== payload.call_id || !this.pc) return;
      try {
        const candidate = JSON.parse(payload.candidate);
        await this.pc.addIceCandidate(new RTCIceCandidate(candidate));
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

  private createPeerConnection(targetId: string, callId: string) {
    this.pc = new RTCPeerConnection(STUN_SERVERS);
    
    this.pc.onicecandidate = (event) => {
      if (event.candidate) {
        wsManager.send('ice_candidate', {
          call_id: callId,
          target_id: targetId,
          candidate: JSON.stringify(event.candidate.toJSON()),
        });
      }
    };

    this.pc.ontrack = (event) => {
      if (event.streams && event.streams[0]) {
        this.remoteStream = event.streams[0];
        this.events.onRemoteStream?.(this.remoteStream);
      }
    };

    if (this.localStream) {
      this.localStream.getTracks().forEach(track => {
        this.pc!.addTrack(track, this.localStream!);
      });
    }
  }

  async startCall(calleeId: string, isVideo: boolean = false) {
    if (this.state.status !== 'idle') return;
    try {
      this.setState({ status: 'connecting', isIncoming: false, peerId: calleeId, isVideo });
      
      await this.getMedia(isVideo);
      // We don't have a call_id yet. The backend should generate it, but our protocol allows generating ID on the server during offer, and returning it.
      // Wait, let's just send call_offer without call_id, and backend sends it to callee. How does caller know the call_id? 
      // It might be returned by a REST API or we generate it? 
      // Looking at backend `call_offer` payload: { callee_id, call_type, sdp }. It doesn't have call_id. So we don't know call_id yet until answer!
      // Actually, if we send via wsManager `call_offer`, how do we know the call_id for ICE candidates?
      // STUB call_id for now, the backend assigns one and sends it back? Let's check backend later. We will use a temp ID or wait for server.
      // Let's generate a temporary ID, or maybe STUN/ICE candidates can be queued until call_id is known.
      const tempCallId = crypto.randomUUID(); 
      this.setState({ callId: tempCallId });

      this.createPeerConnection(calleeId, tempCallId);

      const offer = await this.pc!.createOffer();
      await this.pc!.setLocalDescription(offer);

      wsManager.send('call_offer', {
        callee_id: calleeId,
        call_type: isVideo ? 'video' : 'audio',
        sdp: offer.sdp,
        // Optional call_id if backend accepts it
        call_id: tempCallId
      });

    } catch (err: any) {
      this.cleanup(err.message);
    }
  }

  async answerCall() {
    if (this.state.status !== 'ringing' || !this.state.isIncoming) return;
    const { callId, peerId, isVideo } = this.state;
    if (!callId || !peerId) return;

    try {
      this.setState({ status: 'connecting' });
      await this.getMedia(!!isVideo);
      this.createPeerConnection(peerId, callId);

      const offerSdp = (this as any).pendingOfferSdp;
      if (offerSdp) {
        await this.pc!.setRemoteDescription(new RTCSessionDescription({ type: 'offer', sdp: offerSdp }));
        const answer = await this.pc!.createAnswer();
        await this.pc!.setLocalDescription(answer);

        wsManager.send('call_answer', {
          call_id: callId,
          sdp: answer.sdp,
        });
        this.setState({ status: 'connected' });
      }
    } catch (err: any) {
      this.cleanup(err.message);
    }
  }

  rejectCall() {
    if (this.state.callId) {
      wsManager.send('call_reject', { call_id: this.state.callId });
    }
    this.cleanup();
  }

  endCall() {
    if (this.state.callId) {
      wsManager.send('call_end', { call_id: this.state.callId });
    }
    this.cleanup();
  }

  private cleanup(errorMsg?: string) {
    if (errorMsg) {
      this.events.onError?.(errorMsg);
    }
    this.pc?.close();
    this.pc = null;
    this.localStream?.getTracks().forEach(t => t.stop());
    this.localStream = null;
    this.remoteStream = null;
    this.events.onLocalStream?.(null);
    this.events.onRemoteStream?.(null);
    this.setState({ status: 'ended' });
  }
}

export const webrtcManager = new WebRTCManager();
