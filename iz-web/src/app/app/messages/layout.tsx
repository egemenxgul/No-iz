'use client';
import { useEffect, useState, useRef } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { wsManager } from '@/lib/websocket';
import styles from './messages-layout.module.css';
import { useI18n } from '@/lib/i18n/I18nContext';
import { Conversation, FriendStoryFeed, Group } from '@/types';
import StoryViewer from '@/components/StoryViewer';

export default function MessagesLayout({ children }: { children: React.ReactNode }) {
  const { t } = useI18n();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [groups, setGroups] = useState<Group[]>([]);
  const [stories, setStories] = useState<FriendStoryFeed[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeStoryFeed, setActiveStoryFeed] = useState<number | null>(null);
  const [showNewChat, setShowNewChat] = useState(false);
  const [showNewGroup, setShowNewGroup] = useState(false);
  const [groupName, setGroupName] = useState('');
  const [groupDesc, setGroupDesc] = useState('');
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
      
      const groupRes = await api.groups.list();
      setGroups(groupRes.groups || []);

      const storyRes = await api.stories.feed();
      setStories(storyRes || []);
    } catch (err) {
      console.error('Failed to fetch data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConversations();
    const off = wsManager.on('new_message', () => { fetchConversations(); });
    const offKey = wsManager.on('group_key_distribution', (payload: any) => {
       // Save received sender key for a group
       if (!payload || !payload.group_id || !payload.sender_id || !payload.key) return;
       const store = JSON.parse(localStorage.getItem('iz_group_keys') || '{}');
       if (!store[payload.group_id]) store[payload.group_id] = {};
       store[payload.group_id][payload.sender_id] = payload.key;
       localStorage.setItem('iz_group_keys', JSON.stringify(store));
    });
    return () => { off(); offKey(); };
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

  async function createGroup() {
    if (!groupName.trim()) return;
    try {
      const g = await api.groups.create(groupName, groupDesc, false);
      setShowNewGroup(false);
      setGroupName('');
      setGroupDesc('');
      setGroups(prev => [g, ...prev]);
      router.push(`/app/groups/${g.id}`);
    } catch (err) {
      console.error('Create group failed', err);
    }
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
          <div style={{ display: 'flex', gap: '8px' }}>
            <button className={styles.newChatBtn} onClick={() => setShowNewGroup(true)} title={t('app.new_group')}>
              👥
            </button>
            <button className={styles.newChatBtn} onClick={() => setShowNewChat(true)} title={t('app.new_chat')}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M12 5v14m-7-7h14" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>

        {/* New Group Modal */}
        {showNewGroup && (
          <div className={styles.modalOverlay} onClick={() => setShowNewGroup(false)}>
            <div className={styles.modal} onClick={e => e.stopPropagation()}>
              <div className={styles.modalHeader}>
                <h3 className={styles.modalTitle}>{t('app.create_group')}</h3>
                <button className={styles.modalClose} onClick={() => setShowNewGroup(false)}>✕</button>
              </div>
              <div className={styles.modalSearch} style={{ display: 'flex', flexDirection: 'column', gap: 12, padding: 16 }}>
                <input
                  type="text"
                  className={styles.searchInput}
                  placeholder={t('app.group_name_placeholder')}
                  value={groupName}
                  onChange={e => setGroupName(e.target.value)}
                  autoFocus
                />
                <input
                  type="text"
                  className={styles.searchInput}
                  placeholder={t('app.group_desc')}
                  value={groupDesc}
                  onChange={e => setGroupDesc(e.target.value)}
                />
                <button 
                  className={styles.newChatBtn} 
                  style={{ width: '100%', padding: '12px', background: 'var(--accent)', color: 'white', borderRadius: 12 }}
                  onClick={createGroup}
                  disabled={!groupName.trim()}
                >
                  {t('app.create')}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Stories Ring */}
        {!loading && stories.length > 0 && (
          <div className={styles.storyRingContainer}>
            {stories.map((feed, idx) => (
              <div key={feed.user_id} className={styles.storyItem} onClick={() => setActiveStoryFeed(idx)}>
                <div className={styles.storyAvatarWrapper}>
                  <div className={styles.storyAvatar}>
                    {feed.display_name?.[0]?.toUpperCase() || feed.username[0].toUpperCase()}
                  </div>
                </div>
                <span className={styles.storyName}>{feed.display_name || feed.username}</span>
              </div>
            ))}
          </div>
        )}

        <div className={styles.list}>
          {loading && Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className={`${styles.item} skeleton`} style={{ height: 64, margin: '8px 12px', borderRadius: 12 }} />
          ))}
          
          {!loading && conversations.length === 0 && groups.length === 0 && (
            <div className={styles.empty}>
              <div style={{ fontSize: 32, marginBottom: 8 }}>💬</div>
              <div>{t('app.no_chats')}</div>
              <button className={styles.emptyBtn} onClick={() => setShowNewChat(true)}>{t('app.start_chat')}</button>
            </div>
          )}

          {/* Groups list */}
          {groups.map((g) => (
            <Link
              key={g.id}
              href={`/app/groups/${g.id}`}
              className={`${styles.item} ${id === g.id ? styles.itemActive : ''}`}
            >
              <div className={styles.avatar}>
                👥
              </div>
              <div className={styles.content}>
                <div className={styles.top}>
                  <span className={styles.name}>{g.name}</span>
                </div>
                <p className={styles.lastMsg}>{g.description || t('app.group')}</p>
              </div>
            </Link>
          ))}

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

      {/* Story Viewer Overlay */}
      {activeStoryFeed !== null && (
        <StoryViewer
          feed={stories[activeStoryFeed]}
          onClose={() => setActiveStoryFeed(null)}
          onNextFeed={activeStoryFeed < stories.length - 1 ? () => setActiveStoryFeed(activeStoryFeed + 1) : undefined}
          onPrevFeed={activeStoryFeed > 0 ? () => setActiveStoryFeed(activeStoryFeed - 1) : undefined}
        />
      )}
    </div>
  );
}
