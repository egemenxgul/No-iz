'use client';
import { useEffect, useState, useRef } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { wsManager } from '@/lib/websocket';
import styles from './messages-layout.module.css';
import { useI18n } from '@/lib/i18n/I18nContext';
import { Conversation, User } from '@/types';

export default function MessagesLayout({ children }: { children: React.ReactNode }) {
  const { t } = useI18n();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [showNewChat, setShowNewChat] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<{ id: string; username: string; display_name: string; avatar_url: string }[]>([]);
  const [searching, setSearching] = useState(false);
  const { id } = useParams();
  const router = useRouter();
  const searchRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const fetchConversations = async () => {
    try {
      const res = await api.messages.conversations();
      setConversations(res.conversations || []);
    } catch (err) {
      console.error('Failed to fetch conversations:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConversations();
    const off = wsManager.on('new_message', () => { fetchConversations(); });
    return () => off();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Debounced search
  useEffect(() => {
    if (!showNewChat) return;
    clearTimeout(searchRef.current);
    if (searchQuery.length < 2) { setSearchResults([]); return; }
    setSearching(true);
    searchRef.current = setTimeout(async () => {
      try {
        const res = await api.auth.searchUsers(searchQuery);
        setSearchResults(res.users || []);
      } catch { setSearchResults([]); }
      finally { setSearching(false); }
    }, 300);
  }, [searchQuery, showNewChat]);

  function openNewChat(userId: string) {
    setShowNewChat(false);
    setSearchQuery('');
    setSearchResults([]);
    router.push(`/app/messages/${userId}`);
  }

  return (
    <div className={styles.container}>
      {/* New Chat Modal */}
      {showNewChat && (
        <div className={styles.modalOverlay} onClick={() => { setShowNewChat(false); setSearchQuery(''); setSearchResults([]); }}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>{t('app.new_chat')}</h3>
              <button className={styles.modalClose} onClick={() => { setShowNewChat(false); setSearchQuery(''); setSearchResults([]); }}>✕</button>
            </div>
            <div className={styles.modalSearch}>
              <input
                type="text"
                className={styles.searchInput}
                placeholder={t('app.search_user')}
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                autoFocus
              />
            </div>
            <div className={styles.searchResults}>
              {searching && <div className={styles.searchHint}>{t('app.searching')}</div>}
              {!searching && searchQuery.length >= 2 && searchResults.length === 0 && (
                <div className={styles.searchHint}>{t('app.user_not_found')}</div>
              )}
              {!searching && searchQuery.length < 2 && (
                <div className={styles.searchHint}>{t('app.min_2_chars')}</div>
              )}
              {searchResults.map(u => (
                <button key={u.id} className={styles.searchResultItem} onClick={() => openNewChat(u.id)}>
                  <div className={styles.searchAvatar}>{u.display_name?.[0]?.toUpperCase() || u.username?.[0]?.toUpperCase()}</div>
                  <div>
                    <div className={styles.searchName}>{u.display_name}</div>
                    <div className={styles.searchHandle}>@{u.username}</div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Messages Sidebar */}
      <aside className={styles.sidebar}>
        <div className={styles.header}>
          <h2 className={styles.title}>{t('app.messages')}</h2>
          <button
            className={styles.newChatBtn}
            title={t('app.new_chat')}
            id="new-chat-btn"
            onClick={() => setShowNewChat(true)}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" /><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
            </svg>
          </button>
        </div>

        <div className={styles.list}>
          {loading && Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className={`${styles.item} skeleton`} style={{ height: 64, margin: '8px 12px', borderRadius: 12 }} />
          ))}
          
          {!loading && conversations.length === 0 && (
            <div className={styles.empty}>
              <div style={{ fontSize: 32, marginBottom: 8 }}>💬</div>
              <div>{t('app.no_chats')}</div>
              <button className={styles.emptyBtn} onClick={() => setShowNewChat(true)}>{t('app.start_chat')}</button>
            </div>
          )}

          {conversations.map((c) => (
            <Link
              key={c.other_user_id}
              href={`/app/messages/${c.other_user_id}`}
              className={`${styles.item} ${id === c.other_user_id ? styles.itemActive : ''}`}
            >
              <div className={styles.avatar}>
                {c.other_display_name?.[0]?.toUpperCase() || c.other_username?.[0]?.toUpperCase()}
              </div>
              <div className={styles.content}>
                <div className={styles.top}>
                  <span className={styles.name}>{c.other_display_name || c.other_username}</span>
                  <span className={styles.time}>
                    {c.last_message_at ? new Date(c.last_message_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                  </span>
                </div>
                <p className={styles.lastMsg}>{c.last_message_type === 'text' ? t('app.msg_text') : t('app.msg_file')}</p>
              </div>
            </Link>
          ))}
        </div>
      </aside>

      {/* Chat Area */}
      <div className={styles.contentArea}>
        {children}
      </div>
    </div>
  );
}
