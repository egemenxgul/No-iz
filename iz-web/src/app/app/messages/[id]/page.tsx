'use client';
import { useEffect, useState, useRef, KeyboardEvent } from 'react';
import { useParams } from 'next/navigation';
import { api } from '@/lib/api';
import { wsManager } from '@/lib/websocket';
import { getAuth } from '@/store/auth';
import { sendEncrypted, receiveDecrypted, establishSession, loadSessions } from '@/lib/crypto/session';
import { Message } from '@/types';
import { webrtcManager } from '@/lib/webrtc';
import styles from './chat.module.css';

import { useI18n } from '@/lib/i18n/I18nContext';

export default function ConversationPage() {
  const { id } = useParams<{ id: string }>();
  const auth = getAuth();
  const { t } = useI18n();
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput]       = useState('');
  const [loading, setLoading]   = useState(true);
  
  const [isTyping, setIsTyping] = useState(false);
  const [isOnline, setIsOnline] = useState(false);

  // UX-1: Infinite scroll state
  const [hasMore, setHasMore]           = useState(true);
  const [loadingMore, setLoadingMore]   = useState(false);
  const oldestCursorRef                 = useRef<string | undefined>(undefined);
  const scrollAreaRef                   = useRef<HTMLDivElement>(null);
  
  const bottomRef = useRef<HTMLDivElement>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const lastTypingSentRef = useRef<number>(0);

  // Load history and decrypt messages
  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const r = await api.messages.history(id);
        const msgs = r.messages || [];
        
        // Send read receipts for unread msgs from this user
        msgs.forEach((m: any) => {
          if (!m.read_at && m.sender_id === id && m.recipient_id === auth?.user_id) {
            wsManager.send('message_read', { message_id: m.id });
          }
        });
        
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
        // UX-1: Track oldest message for cursor pagination
        if (decryptedMsgs.length > 0) {
          oldestCursorRef.current = msgs[msgs.length - 1].created_at;
        }
        setHasMore(msgs.length >= 50);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [id]);

  // UX-1: Load older messages when scrolled to top
  async function loadMore() {
    if (loadingMore || !hasMore || !oldestCursorRef.current) return;
    setLoadingMore(true);
    const prevScrollHeight = scrollAreaRef.current?.scrollHeight ?? 0;
    try {
      const r = await api.messages.history(id, oldestCursorRef.current);
      const msgs = r.messages || [];
      if (msgs.length === 0) { setHasMore(false); return; }

      const decryptedMsgs = await Promise.all(msgs.map(async (m: Message) => {
        try { return { ...m, plaintext: await receiveDecrypted(id, m) }; }
        catch { return m; }
      }));

      setMessages(prev => [...decryptedMsgs.reverse(), ...prev]);
      oldestCursorRef.current = msgs[msgs.length - 1].created_at;
      setHasMore(msgs.length >= 50);

      // Restore scroll position so user doesn't jump
      requestAnimationFrame(() => {
        if (scrollAreaRef.current) {
          const newScrollHeight = scrollAreaRef.current.scrollHeight;
          scrollAreaRef.current.scrollTop = newScrollHeight - prevScrollHeight;
        }
      });
    } catch (err) {
      console.error('Load more failed:', err);
    } finally {
      setLoadingMore(false);
    }
  }

  // Subscribe to new messages and events
  useEffect(() => {
    const unsubNewMessage = wsManager.on('new_message', async (payloadRaw: unknown) => {
      const payload = payloadRaw as Message;
      if (payload.sender_id === id || payload.recipient_id === id) {
        try {
          const plaintext = await receiveDecrypted(id, payload);
          setMessages(prev => [...prev, { ...payload, plaintext }]);
        } catch {
          setMessages(prev => [...prev, payload]);
        }

        // Send read receipt if we are the recipient
        if (payload.recipient_id === auth?.user_id && payload.sender_id === id) {
          wsManager.send('message_read', { message_id: payload.id });
        }
      }
    });

    const unsubTyping = wsManager.on('user_typing', (payloadRaw: unknown) => {
      const p = payloadRaw as any;
      if (p.sender_id === id) setIsTyping(p.is_typing);
    });

    const unsubPresence = wsManager.on('presence', (payloadRaw: unknown) => {
      const p = payloadRaw as any;
      if (p.user_id === id) setIsOnline(p.online);
    });

    const unsubRead = wsManager.on('message_read', (payloadRaw: unknown) => {
      const p = payloadRaw as any;
      if (p.reader_id === id) {
        setMessages(prev => prev.map(m => m.id === p.message_id ? { ...m, read_at: new Date().toISOString() } : m));
      }
    });

    return () => {
      unsubNewMessage();
      unsubTyping();
      unsubPresence();
      unsubRead();
    };
  }, [id, auth]);

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

      // 3. Send over WebSocket — with outbound queue fallback (UX-2)
      const sent = wsManager.send('send_message', {
        recipient_id: id,
        ...encrypted,
        msg_type: 'text',
      }, true); // persistOnOffline = true

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
        // UX-2: mark as pending if queued
        _pending: !sent,
      } as Message & { _pending?: boolean }]);
      setInput('');
    } catch (err) {
      console.error('Send failed:', err);
    }
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const val = e.target.value;
    setInput(val);
    
    const now = Date.now();
    if (val.length > 0 && now - lastTypingSentRef.current > 3000) {
      wsManager.send('user_typing', { is_typing: true, recipient_id: id });
      lastTypingSentRef.current = now;
      
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      typingTimeoutRef.current = setTimeout(() => {
        wsManager.send('user_typing', { is_typing: false, recipient_id: id });
        lastTypingSentRef.current = 0;
      }, 3500);
    } else if (val.length === 0) {
      wsManager.send('user_typing', { is_typing: false, recipient_id: id });
      lastTypingSentRef.current = 0;
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    }
  };

  function handleKey(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) { 
      e.preventDefault(); 
      sendMessage(); 
      wsManager.send('user_typing', { is_typing: false, recipient_id: id });
      lastTypingSentRef.current = 0;
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    }
  }

  async function togglePin(msg: Message) {
    try {
      if (msg.is_pinned) {
        await api.messages.unpin(msg.id);
        setMessages(prev => prev.map(m => m.id === msg.id ? { ...m, is_pinned: false } : m));
      } else {
        await api.messages.pin(msg.id);
        setMessages(prev => prev.map(m => m.id === msg.id ? { ...m, is_pinned: true } : { ...m, is_pinned: false }));
      }
    } catch (err) {
      console.error('Failed to pin/unpin', err);
    }
  }

  const pinnedMsg = messages.find(m => m.is_pinned);

  return (
    <div className={styles.container}>
      {/* Chat Header for Calling */}
      <div className={styles.chatHeader}>
        <div className={styles.chatHeaderInfo}>
          <div className={styles.chatHeaderTitle}>{t('app.messages')}</div>
          <div className={styles.chatHeaderSubtitle}>
            {isTyping ? (
              <span className={`${styles['text-accent']} ${styles['font-semibold']} ${styles.italic}`}>{t('typing') || 'yazıyor...'}</span>
            ) : isOnline ? (
              <span className={`${styles['text-success']} ${styles['font-semibold']} ${styles.flex} ${styles['items-center']} ${styles['gap-1']}`}>
                <div style={{width: 6, height: 6, borderRadius: '50%', backgroundColor: '#10b981'}} /> Çevrimiçi
              </span>
            ) : null}
          </div>
        </div>
        <div className={styles.chatHeaderActions}>
          <button className={styles.callBtn} onClick={() => webrtcManager.startCall(id as string, false)} title="Sesli Arama">
            📞
          </button>
          <button className={styles.callBtn} onClick={() => webrtcManager.startCall(id as string, true)} title="Görüntülü Arama">
            📹
          </button>
        </div>
      </div>

      {/* Pinned Banner */}
      {pinnedMsg && (
        <div className={styles.pinnedBanner} onClick={() => {
          // Optional: Scroll to message logic could be added here
        }}>
          <div className={styles.pinnedIcon}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" />
            </svg>
          </div>
          <div className={styles.pinnedContent}>
            <span className={styles.pinnedLabel}>{t('app.pinned_message') || 'Pinned Message'}</span>
            <span className={styles.pinnedText}>{pinnedMsg.plaintext ?? '[Şifreli mesaj]'}</span>
          </div>
          <button className={styles.pinBtn} onClick={(e) => { e.stopPropagation(); togglePin(pinnedMsg); }}>✕</button>
        </div>
      )}

      {/* Messages — UX-1: infinite scroll via onScroll */}
      <div
        className={styles.messages}
        ref={scrollAreaRef}
        onScroll={(e) => {
          const el = e.currentTarget;
          if (el.scrollTop < 80 && hasMore && !loadingMore) loadMore();
        }}
      >
        {/* Load more indicator */}
        {loadingMore && (
          <div style={{ textAlign: 'center', padding: '8px', opacity: 0.5, fontSize: '12px' }}>
            <span className={styles.spinner} style={{ width: 14, height: 14 }} /> Eski mesajlar yükleniyor...
          </div>
        )}
        {!hasMore && messages.length > 0 && (
          <div style={{ textAlign: 'center', padding: '8px', opacity: 0.35, fontSize: '11px' }}>
            {t('app.no_more_messages') || 'Sohbetin başlı — daha eski mesaj yok'}
          </div>
        )}
        {loading && <div className={styles.loadingCenter}><span className={styles.spinner} /></div>}
        {messages.map(m => (
          <div
            key={m.id}
            className={`${styles.bubble} ${m.sender_id === auth?.user_id ? styles.bubbleOut : styles.bubbleIn}`}
          >
            <span className={styles.bubbleText}>{m.plaintext ?? <span style={{opacity: 0.4, fontStyle: 'italic', fontSize: '13px'}}>{t('encrypted_placeholder') || 'Şifreli — oturum anahtarı bulunamadı'}</span>}</span>
            <span className={styles.bubbleTime}>
              {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              {/* UX-2: pending icon for offline-queued messages */}
              {(m as Message & { _pending?: boolean })._pending && (
                <span title="Gönderilmeyi bekliyor" style={{ marginLeft: 4, opacity: 0.6 }}>⏳</span>
              )}
              {m.sender_id === auth?.user_id && !(m as Message & { _pending?: boolean })._pending && (
                <span className={`${styles.readStatus} ${m.read_at ? styles.statusRead : styles.statusDelivered}`}>
                  {m.read_at ? (
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6L7 17l-5-5"></path><path d="M22 10l-5 5-1.5-1.5"></path></svg>
                  ) : m.delivered_at ? (
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6L7 17l-5-5"></path><path d="M22 10l-5 5-1.5-1.5"></path></svg>
                  ) : (
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6L9 17l-5-5"></path></svg>
                  )}
                </span>
              )}
            </span>
            <button className={styles.pinBtn} title={m.is_pinned ? "Unpin" : "Pin"} onClick={() => togglePin(m)}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" />
              </svg>
            </button>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className={styles.inputBar}>
        <textarea
          className={styles.textarea}
          value={input}
          onChange={handleInputChange}
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
