/**
 * Web Outbound Message Queue
 * 
 * Mobil (Dart) tarafındaki OutboundQueue'nun Web karşılığıdır.
 * WebSocket bağlantısı olmadığında gönderilemeyen mesajları IndexedDB/localStorage'a
 * kaydeder ve bağlantı geri geldiğinde otomatik olarak tekrar gönderir.
 */

export interface QueuedMessage {
  id: string;
  type: string;
  payload: Record<string, unknown>;
  createdAt: number;
  retries: number;
}

const STORAGE_KEY = 'iz_outbound_queue';
const MAX_RETRIES = 5;

function loadQueue(): QueuedMessage[] {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
  } catch {
    return [];
  }
}

function saveQueue(queue: QueuedMessage[]) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(queue));
  } catch {}
}

export const outboundQueue = {
  /** Add a message to the queue and persist it */
  enqueue(type: string, payload: Record<string, unknown>): QueuedMessage {
    const item: QueuedMessage = {
      id: crypto.randomUUID(),
      type,
      payload,
      createdAt: Date.now(),
      retries: 0,
    };
    const queue = loadQueue();
    queue.push(item);
    saveQueue(queue);
    return item;
  },

  /** Remove a message from the queue (after successful send) */
  dequeue(id: string) {
    const queue = loadQueue().filter(m => m.id !== id);
    saveQueue(queue);
  },

  /** Get all pending messages */
  getAll(): QueuedMessage[] {
    return loadQueue();
  },

  /** Mark a retry and remove if exceeds max */
  markRetried(id: string) {
    const queue = loadQueue().map(m =>
      m.id === id ? { ...m, retries: m.retries + 1 } : m
    ).filter(m => m.retries <= MAX_RETRIES);
    saveQueue(queue);
  },

  /** Flush all queued messages over WebSocket */
  flush(sendFn: (type: string, payload: Record<string, unknown>) => boolean) {
    const queue = loadQueue();
    for (const item of queue) {
      const sent = sendFn(item.type, item.payload);
      if (sent) {
        outboundQueue.dequeue(item.id);
      } else {
        // WS not open yet — stop flushing
        break;
      }
    }
  },

  size(): number {
    return loadQueue().length;
  },
};
