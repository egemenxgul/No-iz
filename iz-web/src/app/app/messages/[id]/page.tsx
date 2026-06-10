'use client';
import { useEffect, useState, useRef, KeyboardEvent } from 'react';
import { useParams } from 'next/navigation';
import { api } from '@/lib/api';
import { wsManager } from '@/lib/websocket';
import { getAuth } from '@/store/auth';
import { sendEncrypted, receiveDecrypted, establishSession, loadSessions } from '@/lib/crypto/session';
import { Message } from '@/types';
import styles from './chat.module.css';

import { useI18n } from '@/lib/i18n/I18nContext';

export default function ConversationPage() {
  const { id } = useParams<{ id: string }>();
  const auth = getAuth();
  const { t } = useI18n();
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput]       = useState('');
  const [loading, setLoading]   = useState(true);
  const bottomRef = useRef<HTMLDivElement>(null);

  // Load history and decrypt messages
  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const r = await api.messages.history(id);
        const msgs = r.messages || [];
        
        // Decrypt messages if possible
        const decryptedMsgs = await Promise.all(msgs.map(async m => {
          try {
            const plaintext = await receiveDecrypted(id, m);
            return { ...m, plaintext };
          } catch {
            return m;
          }
        }));

        setMessages(decryptedMsgs.reverse());
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [id]);

  // Subscribe to new messages
  useEffect(() => {
    return wsManager.on('new_message', async (payloadRaw: unknown) => {
      const payload = payloadRaw as Message;
      if (payload.sender_id === id || payload.recipient_id === id) {
        try {
          const plaintext = await receiveDecrypted(id, payload);
          setMessages(prev => [...prev, { ...payload, plaintext }]);
        } catch {
          setMessages(prev => [...prev, payload]);
        }
      }
    });
  }, [id]);

  // Scroll to bottom
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function sendMessage() {
    if (!input.trim() || !auth) return;

    try {
      // 1. Ensure session exists
      const sessions = loadSessions();
      if (!sessions[id]) {
        // Need local identity to establish session
        const localKeysRaw = localStorage.getItem('iz_keys');
        if (!localKeysRaw) throw new Error('Local keys not found');
        const localKeys = JSON.parse(localKeysRaw);
        // Convert base64 back to Uint8Array for the establishSession function
        // (Assuming establishSession handles it or we fix it there)
        await establishSession(id, localKeys.identityKey);
      }

      // 2. Encrypt
      const encrypted = await sendEncrypted(id, input.trim());

      // 3. Send over WebSocket
      wsManager.send('send_message', {
        recipient_id: id,
        ...encrypted,
        msg_type: 'text',
      });

      // Optimistic update
      setMessages(prev => [...prev, {
        id: crypto.randomUUID(),
        sender_id: auth.user_id,
        recipient_id: id,
        ciphertext: encrypted.ciphertext,
        plaintext: input.trim(),
        msg_type: 'text',
        ratchet_header: encrypted.ratchet_key,
        delivered_at: null,
        read_at: null,
        expires_at: null,
        created_at: new Date().toISOString(),
      }]);
      setInput('');
    } catch (err) {
      console.error('Send failed:', err);
    }
  }

  function handleKey(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  }

  return (
    <div className={styles.container}>
      {/* Messages */}
      <div className={styles.messages}>
        {loading && <div className={styles.loadingCenter}><span className={styles.spinner} /></div>}
        {messages.map(m => (
          <div
            key={m.id}
            className={`${styles.bubble} ${m.sender_id === auth?.user_id ? styles.bubbleOut : styles.bubbleIn}`}
          >
            <span className={styles.bubbleText}>{m.plaintext ?? atob(m.ciphertext)}</span>
            <span className={styles.bubbleTime}>
              {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              {m.sender_id === auth?.user_id && (
                <span className={styles.readStatus}>{m.read_at ? '✓✓' : m.delivered_at ? '✓✓' : '✓'}</span>
              )}
            </span>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className={styles.inputBar}>
        <textarea
          className={styles.textarea}
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={handleKey}
          placeholder={t('app.chat_placeholder')}
          rows={1}
          id="message-input"
        />
        <button
          className={styles.sendBtn}
          onClick={sendMessage}
          disabled={!input.trim()}
          id="send-btn"
        >
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M16 9L2 2l4 7-4 7 14-7z" fill="currentColor"/>
          </svg>
        </button>
      </div>
    </div>
  );
}
