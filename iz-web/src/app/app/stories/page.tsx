'use client';

import React, { useEffect, useState, useRef } from 'react';
import { api } from '@/lib/api';
import { useI18n } from '@/lib/i18n/I18nContext';
import styles from './page.module.css';
import { encryptAndUploadMedia, fetchAndDecryptMedia } from '@/lib/crypto/media';
import { getStoryKey, saveStoryKey, encryptStoryCaption, decryptStoryCaption } from '@/lib/crypto/story';
import { sendEncrypted } from '@/lib/crypto/session';

type Story = {
  id: string;
  user_id: string;
  media_url: string;
  caption: string;
  media_type: string;
  created_at: string;
  expires_at: string;
};

type FriendStoryFeed = {
  user_id: string;
  username: string;
  display_name: string;
  avatar_url: string;
  stories: Story[];
};

export default function StoriesPage() {
  const { t } = useI18n();
  const [feeds, setFeeds] = useState<FriendStoryFeed[]>([]);
  const [loading, setLoading] = useState(true);

  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [caption, setCaption] = useState('');
  const [uploading, setUploading] = useState(false);

  const [viewingStory, setViewingStory] = useState<{ feed: FriendStoryFeed, index: number } | null>(null);
  const [decryptedMediaUrl, setDecryptedMediaUrl] = useState<string | null>(null);
  const [decryptedCaption, setDecryptedCaption] = useState<string>('');
  const [viewerLoading, setViewerLoading] = useState(false);

  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    loadFeeds();
  }, []);

  async function loadFeeds() {
    try {
      const data = await api.stories.feed();
      setFeeds(data);
    } catch (e) {
      console.error('Failed to load stories', e);
    } finally {
      setLoading(false);
    }
  }

  // CREATE STORY
  async function handleCreateStory() {
    if (!selectedFile) return;
    setUploading(true);
    try {
      // 1. Encrypt and upload media
      const { mediaUrl, base64Key, mimeType } = await encryptAndUploadMedia(selectedFile, selectedFile.name);

      // 2. Encrypt caption
      let encCaption = caption;
      if (caption.trim().length > 0) {
        encCaption = await encryptStoryCaption(caption.trim(), base64Key);
      }

      const token = localStorage.getItem('iz_token') || sessionStorage.getItem('iz_token');
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'https://api.no-iz.app'}/api/stories`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          media_url: mediaUrl,
          caption: encCaption,
          media_type: mimeType.startsWith('video/') ? 'video' : 'image'
        })
      });

      if (!res.ok) throw new Error('Failed to post story');
      const createdStory = await res.json();
      
      // 4. Save key locally
      saveStoryKey(createdStory.id, base64Key);

      // 5. Send the key to all active conversations
      const convs = await api.messages.conversations();
      for (const c of convs.conversations) {
        if (!c.is_group && c.friendship_status === 'accepted') {
          try {
            const controlPlaintext = JSON.stringify({
              type: 'story_key',
              story_id: createdStory.id,
              media_key: base64Key
            });
            await sendEncrypted(c.other_user_id!, controlPlaintext, 'story_key');
          } catch (e) {
            console.warn(`Failed to send story key to ${c.other_user_id}`, e);
          }
        }
      }

      setIsCreateModalOpen(false);
      setSelectedFile(null);
      setCaption('');
      loadFeeds();
    } catch (e) {
      console.error('Error creating story:', e);
      alert('Hikaye oluşturulurken hata oluştu.');
    } finally {
      setUploading(false);
    }
  }

  // VIEW STORY
  async function handleViewStory(feed: FriendStoryFeed, index: number) {
    const story = feed.stories[index];
    setViewingStory({ feed, index });
    setViewerLoading(true);
    setDecryptedMediaUrl(null);
    setDecryptedCaption('');

    try {
      const key = getStoryKey(story.id);
      if (!key) {
        setDecryptedCaption('Şifreli Hikaye (Anahtar Bulunamadı)');
        return;
      }

      // Decrypt media
      const objectUrl = await fetchAndDecryptMedia(story.media_url, key, story.media_type === 'video' ? 'video/mp4' : 'image/jpeg');
      setDecryptedMediaUrl(objectUrl);

      // Decrypt caption
      if (story.caption) {
        const plainCap = await decryptStoryCaption(story.caption, key);
        setDecryptedCaption(plainCap);
      }

      // Mark as viewed in backend
      await api.stories.view(story.id).catch(() => {});

    } catch (e) {
      console.error('Failed to view story', e);
      setDecryptedCaption('Hikaye deşifre edilemedi.');
    } finally {
      setViewerLoading(false);
    }
  }

  function closeViewer() {
    setViewingStory(null);
    if (decryptedMediaUrl) {
      URL.revokeObjectURL(decryptedMediaUrl);
    }
    setDecryptedMediaUrl(null);
  }

  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <h1>{t('app.stories') || 'Hikayeler'}</h1>
        <button className={styles.addBtn} onClick={() => setIsCreateModalOpen(true)}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 5v14M5 12h14" />
          </svg>
          Yeni Hikaye
        </button>
      </header>

      {loading ? (
        <div>Yükleniyor...</div>
      ) : feeds.length === 0 ? (
        <div style={{ textAlign: 'center', opacity: 0.5, marginTop: '3rem' }}>
          Hiç hikaye yok. İlk paylaşan sen ol!
        </div>
      ) : (
        <div className={styles.feed}>
          {feeds.map((feed) => (
            <div key={feed.user_id} className={styles.userFeed}>
              <div className={styles.userInfo}>
                <div className={`${styles.avatar} ${feed.stories.length > 0 ? styles.hasUnviewed : ''}`}>
                  {feed.display_name?.[0]?.toUpperCase() || '?'}
                </div>
                <div>
                  <div className={styles.userName}>{feed.display_name}</div>
                  <div className={styles.userHandle}>@{feed.username}</div>
                </div>
              </div>
              <div className={styles.storiesGrid}>
                {feed.stories.map((story, idx) => {
                  const key = getStoryKey(story.id);
                  return (
                    <div 
                      key={story.id} 
                      className={`${styles.storyCard} ${!key ? styles.unviewed : ''}`}
                      onClick={() => handleViewStory(feed, idx)}
                    >
                      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(45deg, #4c1d95, #6d28d9)', opacity: 0.5 }} />
                      <div className={styles.storyTime}>
                        {new Date(story.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </div>
                      {!key && (
                        <div style={{ position: 'absolute', top: 4, right: 4, fontSize: '0.7rem' }}>🔒</div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* CREATE MODAL */}
      {isCreateModalOpen && (
        <div className={styles.modalOverlay}>
          <div className={styles.createModal}>
            <h2>Yeni Hikaye Paylaş (E2EE)</h2>
            <input 
              type="file" 
              ref={fileInputRef}
              className={styles.fileInput}
              accept="image/*,video/*"
              onChange={(e) => setSelectedFile(e.target.files?.[0] || null)}
            />
            <div className={styles.fileLabel} onClick={() => fileInputRef.current?.click()}>
              {selectedFile ? selectedFile.name : 'Fotoğraf veya Video Seçmek İçin Tıklayın'}
            </div>
            
            <textarea
              className={styles.captionInput}
              placeholder="Hikayenize bir açıklama ekleyin..."
              rows={3}
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
            />

            <div className={styles.modalActions}>
              <button className={styles.cancelBtn} onClick={() => setIsCreateModalOpen(false)}>
                İptal
              </button>
              <button 
                className={styles.addBtn} 
                disabled={!selectedFile || uploading}
                onClick={handleCreateStory}
              >
                {uploading ? 'Şifrelenip Yükleniyor...' : 'Paylaş'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* VIEWER MODAL */}
      {viewingStory && (
        <div className={styles.viewerModal}>
          <button className={styles.closeViewerBtn} onClick={closeViewer}>✕</button>
          
          <div className={styles.viewerContent}>
            {viewerLoading ? (
              <div style={{ color: 'white' }}>Deşifre ediliyor... 🔒</div>
            ) : decryptedMediaUrl ? (
              viewingStory.feed.stories[viewingStory.index].media_type === 'video' ? (
                <video className={styles.viewerMedia} src={decryptedMediaUrl} autoPlay controls />
              ) : (
                <img className={styles.viewerMedia} src={decryptedMediaUrl} alt="Story" />
              )
            ) : (
              <div style={{ color: 'white', padding: '2rem', textAlign: 'center' }}>
                <span style={{ fontSize: '3rem' }}>🔒</span>
                <p>{decryptedCaption}</p>
                <p style={{ opacity: 0.5, fontSize: '0.9rem', marginTop: '1rem' }}>Bu hikayenin kilit anahtarı sizde yok.</p>
              </div>
            )}
            
            {decryptedCaption && decryptedMediaUrl && (
              <div className={styles.viewerCaption}>{decryptedCaption}</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
