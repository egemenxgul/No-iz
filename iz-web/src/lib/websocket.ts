import { getToken } from '@/store/auth';
import { WSEnvelope } from '@/types';
import { outboundQueue } from './outbound-queue';

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? 'wss://api.no-iz.app/api/ws';

type EventHandler = (payload: unknown) => void;

class WebSocketManager {
  private ws: WebSocket | null = null;
  private listeners = new Map<string, Set<EventHandler>>();
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private pingTimer: ReturnType<typeof setInterval> | null = null;
  private reconnectDelay = 1000;
  private intentionalClose = false;

  connect() {
    const token = getToken();
    if (!token) return;

    this.intentionalClose = false;
    const url = `${WS_URL}?token=${encodeURIComponent(token)}`;
    this.ws = new WebSocket(url);

    this.ws.onopen = () => {
      this.reconnectDelay = 1000;
      this.emit('__connected', null);
      this.startPing();
      // UX-2: Flush any messages that were queued while offline
      outboundQueue.flush((type, payload) => {
        if (this.ws?.readyState === WebSocket.OPEN) {
          this.ws.send(JSON.stringify({ type, payload }));
          return true;
        }
        return false;
      });
    };

    this.ws.onmessage = (ev) => {
      try {
        const env: WSEnvelope = JSON.parse(ev.data);
        this.emit(env.type, env.payload);
      } catch {}
    };

    this.ws.onclose = () => {
      this.stopPing();
      this.emit('__disconnected', null);
      if (!this.intentionalClose) this.scheduleReconnect();
    };

    this.ws.onerror = () => {
      this.ws?.close();
    };
  }

  disconnect() {
    this.intentionalClose = true;
    this.stopPing();
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.ws?.close();
    this.ws = null;
  }

  /**
   * Sends a WS message. If the socket is not open, the message is persisted
   * to the outbound queue and will be retried automatically on reconnect.
   * Returns true if the message was sent immediately, false if queued.
   */
  send(type: string, payload: unknown, persistOnOffline = false): boolean {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type, payload }));
      return true;
    }
    if (persistOnOffline) {
      outboundQueue.enqueue(type, payload as Record<string, unknown>);
    }
    return false;
  }

  on(event: string, handler: EventHandler) {
    if (!this.listeners.has(event)) this.listeners.set(event, new Set());
    this.listeners.get(event)!.add(handler);
    return () => this.off(event, handler);
  }

  off(event: string, handler: EventHandler) {
    this.listeners.get(event)?.delete(handler);
  }

  private emit(event: string, payload: unknown) {
    this.listeners.get(event)?.forEach(h => h(payload));
  }

  private scheduleReconnect() {
    this.reconnectTimer = setTimeout(() => {
      this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30_000);
      this.connect();
    }, this.reconnectDelay);
  }

  private startPing() {
    this.pingTimer = setInterval(() => this.send('ping', null), 25_000);
  }

  private stopPing() {
    if (this.pingTimer) clearInterval(this.pingTimer);
  }

  isConnected() {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}

// Singleton
export const wsManager = new WebSocketManager();

