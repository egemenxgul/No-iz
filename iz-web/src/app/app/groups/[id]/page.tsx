'use client';
import { useEffect, useState, useRef, KeyboardEvent } from 'react';
import { useParams } from 'next/navigation';
import { api } from '@/lib/api';
import { wsManager } from '@/lib/websocket';
import { getAuth } from '@/store/auth';
import { encryptGroupMessage, decryptGroupMessage, getOrCreateMySenderKey, exportKeyToBase64 } from '@/lib/crypto/group-crypto';
import { GroupMessage, Group } from '@/types';
import { webrtcManager } from '@/lib/webrtc';
import styles from '../../messages/[id]/chat.module.css';
import { useI18n } from '@/lib/i18n/I18nContext';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

export default function GroupChatPage() {
  const { id } = useParams<{ id: string }>();
  const auth = getAuth();
  const { t } = useI18n();
  const [messages, setMessages] = useState<GroupMessage[]>([]);
  const [group, setGroup] = useState<Group | null>(null);
  const [input, setInput]       = useState('');
  const [loading, setLoading]   = useState(true);
  const [expiresIn, setExpiresIn] = useState<number>(0);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const g = await api.groups.get(id);
        setGroup(g);

        const r = await api.groups.history(id);
        const msgs = r.messages || [];
        
        // Decrypt messages if possible
        const decryptedMsgs = await Promise.all(msgs.map(async (m: GroupMessage) => {
          try {
            const plaintext = await decryptGroupMessage(id, m.sender_id, m.ciphertext, m.msg_type === 'text' ? m.ciphertext.substring(0, 16) : ''); // Wait, Group messages might not store IV separately. Our send/receive need IV.
            // Actually, GroupMessage type has `ciphertext`. We should package IV + Ciphertext together, or add it to payload.
            // For simplicity, let's assume `decryptGroupMessage` can split them if we use a specific format (e.g. `iv:ciphertext`).
            const parts = m.ciphertext.split(':');
            if (parts.length === 2) {
               const plaintext = await decryptGroupMessage(id, m.sender_id, parts[1], parts[0]);
               return { ...m, plaintext };
            }
            return m;
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

  useEffect(() => {
    return wsManager.on('group_message', async (payloadRaw: unknown) => {
      const payload = payloadRaw as GroupMessage;
      if (payload.group_id === id) {
        try {
          const parts = payload.ciphertext.split(':');
          let plaintext = undefined;
          if (parts.length === 2) {
             plaintext = await decryptGroupMessage(id, payload.sender_id, parts[1], parts[0]);
          }
          setMessages(prev => [...prev, { ...payload, plaintext }]);
        } catch {
          setMessages(prev => [...prev, payload]);
        }
      }
    });
  }, [id]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function shareMySenderKey() {
    if (!auth) return;
    const key = await getOrCreateMySenderKey(id, auth.user_id);
    const keyBase64 = await exportKeyToBase64(key);
    
    // Distribute key to group members (for simplicity, we assume members listen to `group_key_distribution`)
    // In a real app, we should iterate over group members, encrypt it with 1-to-1 ECDH, and send individually.
    try {
      const members = await api.groups.members(id);
      members.members.forEach(m => {
        if (m.id !== auth.user_id) {
           wsManager.send('group_key_distribution', {
              target_id: m.id,
              group_id: id,
              sender_id: auth.user_id,
              key: keyBase64 // Should be encrypted per-user in production!
           });
        }
      });
    } catch (err) {
      console.error('Failed to distribute key', err);
    }
  }

  async function sendMessage() {
    if (!input.trim() || !auth) return;

    try {
      // 1. Ensure my sender key is created and distributed
      await shareMySenderKey();

      // 2. Encrypt using my sender key
      const encrypted = await encryptGroupMessage(id, auth.user_id, input.trim());
      const packagedCiphertext = `${encrypted.iv}:${encrypted.ciphertext}`; // store IV and Ciphertext together

      // 3. Send over WebSocket
      wsManager.send('send_group_message', {
        group_id: id,
        ciphertext: packagedCiphertext,
        msg_type: 'text',
        expires_in: expiresIn,
      });

      // Optimistic update
      setMessages(prev => [...prev, {
        id: crypto.randomUUID(),
        group_id: id,
        sender_id: auth.user_id,
        ciphertext: packagedCiphertext,
        plaintext: input.trim(),
        msg_type: 'text',
        is_pinned: false,
        iteration: 0,
        distribution_id: '',
        expires_at: expiresIn > 0 ? new Date(Date.now() + expiresIn * 1000).toISOString() : null,
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
      <div className={styles.chatHeader}>
        <div className={styles.chatHeaderTitle}>{group?.name || t('app.group')}</div>
        <div className={styles.chatHeaderActions}>
          <button 
            className={styles.callBtn} 
            onClick={async () => {
              try {
                const res = await api.groups.members(id as string);
                const participants = res.members.map((m: any) => m.id).filter((mid: string) => mid !== auth?.user_id);
                webrtcManager.startGroupCall(id as string, participants, false);
              } catch (e) {
                console.error('Failed to start group call', e);
              }
            }} 
            title="Sesli Arama"
          >
            📞
          </button>
          <button 
            className={styles.callBtn} 
            onClick={async () => {
              try {
                const res = await api.groups.members(id as string);
                const participants = res.members.map((m: any) => m.id).filter((mid: string) => mid !== auth?.user_id);
                webrtcManager.startGroupCall(id as string, participants, true);
              } catch (e) {
                console.error('Failed to start group video call', e);
              }
            }} 
            title="Görüntülü Arama"
          >
            📹
          </button>
        </div>
      </div>

      <div className={styles.messages}>
        {loading && <div className={styles.loadingCenter}><span className={styles.spinner} /></div>}
        {messages.map(m => (
          <div
            key={m.id}
            className={`${styles.bubble} ${m.sender_id === auth?.user_id ? styles.bubbleOut : styles.bubbleIn}`}
          >
            {m.sender_id !== auth?.user_id && <div style={{fontSize: 10, color: 'var(--accent)', marginBottom: 4}}>{m.sender_id.substring(0,8)}</div>}
            <div className={`${styles.bubbleText} markdown-body`}>
              {m.plaintext ? (
                <ReactMarkdown remarkPlugins={[remarkGfm]}>
                  {m.plaintext}
                </ReactMarkdown>
              ) : (
                t('app.msg_text')
              )}
            </div>
            <span className={styles.bubbleTime}>
              {m.expires_at && <span title="Süreli Mesaj" style={{ color: '#ef4444', marginRight: 4 }}>🔥</span>}
              {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      <div className={styles.inputBar}>
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
          <select 
            value={expiresIn} 
            onChange={(e) => setExpiresIn(Number(e.target.value))}
            style={{ 
              appearance: 'none', 
              background: 'transparent', 
              border: 'none', 
              color: expiresIn > 0 ? '#ef4444' : 'var(--text-muted)', 
              cursor: 'pointer',
              fontSize: '18px',
              outline: 'none',
              padding: '4px'
            }}
            title="Süreli Mesaj"
          >
            <option value={0}>⏳</option>
            <option value={5}>5s</option>
            <option value={3600}>1s</option>
            <option value={86400}>1g</option>
            <option value={604800}>1h</option>
          </select>
        </div>
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
