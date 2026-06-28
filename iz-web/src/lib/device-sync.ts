import { wsManager } from './websocket';
import { api } from './api';

export class DeviceSyncManager {
  private pc: RTCPeerConnection | null = null;
  private dataChannel: RTCDataChannel | null = null;
  private historyCallbacks: Map<string, (messages: any[]) => void> = new Map();

  constructor() {
    wsManager.on('device_sync_offer', this.handleOffer.bind(this));
    wsManager.on('device_sync_answer', this.handleAnswer.bind(this));
    wsManager.on('device_sync_candidate', this.handleCandidate.bind(this));
  }

  public async startSync() {
    this.pc = new RTCPeerConnection({
      iceServers: [{ urls: 'stun:stun.l.google.com:19302' }],
    });

    this.pc.onicecandidate = (e) => {
      if (e.candidate) {
        wsManager.send('device_sync_candidate', {
          candidate: JSON.stringify(e.candidate.toJSON())
        });
      }
    };

    this.dataChannel = this.pc.createDataChannel('sync', { negotiated: false });
    this.setupDataChannel();

    const offer = await this.pc.createOffer();
    await this.pc.setLocalDescription(offer);

    wsManager.send('device_sync_offer', {
      sdp: offer.sdp
    });
  }

  private handleOffer(payload: any) {
    // Web initiates offer, mobile answers. If Web receives offer, ignore it (it's our own broadcast)
  }

  private async handleAnswer(payload: any) {
    if (!this.pc) return;
    const sdp = payload.sdp;
    await this.pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp }));
  }

  private async handleCandidate(payload: any) {
    if (!this.pc) return;
    const candidateStr = payload.candidate;
    const candidateMap = JSON.parse(candidateStr);
    await this.pc.addIceCandidate(new RTCIceCandidate(candidateMap));
  }

  private setupDataChannel() {
    if (!this.dataChannel) return;
    this.dataChannel.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        if (data.type === 'history_response') {
          const chatId = data.chat_id;
          const callback = this.historyCallbacks.get(chatId);
          if (callback) {
            callback(data.messages);
            this.historyCallbacks.delete(chatId);
          }
        }
      } catch (err) {
        console.error('Data channel parse error', err);
      }
    };
    
    this.dataChannel.onopen = () => {
      console.log('Device Sync DataChannel Open!');
    };
  }

  public getHistory(chatId: string): Promise<any[]> {
    return new Promise((resolve, reject) => {
      if (!this.dataChannel || this.dataChannel.readyState !== 'open') {
        reject(new Error('Sync not established'));
        return;
      }
      
      this.historyCallbacks.set(chatId, resolve);
      this.dataChannel.send(JSON.stringify({
        type: 'get_history',
        chat_id: chatId
      }));
      
      // Timeout
      setTimeout(() => {
        if (this.historyCallbacks.has(chatId)) {
          this.historyCallbacks.delete(chatId);
          reject(new Error('History sync timeout'));
        }
      }, 10000);
    });
  }
}

export const deviceSyncManager = new DeviceSyncManager();
