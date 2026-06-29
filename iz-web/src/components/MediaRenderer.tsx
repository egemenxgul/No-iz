'use client';
import { useEffect, useState } from 'react';
import { fetchAndDecryptMedia } from '@/lib/crypto/media';
import Image from 'next/image';

interface MediaRendererProps {
  payloadJson: string; // The plaintext which is a JSON string for media messages
  msgType: string;
}

export default function MediaRenderer({ payloadJson, msgType }: MediaRendererProps) {
  const [mediaUrl, setMediaUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let objectUrl = '';

    async function load() {
      try {
        const data = JSON.parse(payloadJson);
        const url = data.media_url || data.url;
        const key = data.media_key || data.key;
        const mime = data.mime_type || data.mimeType || 'application/octet-stream';

        if (!url || !key) {
          throw new Error('Eksik medya verisi');
        }

        objectUrl = await fetchAndDecryptMedia(url, key, mime);
        setMediaUrl(objectUrl);
      } catch (err: any) {
        setError(err.message || 'Medya yüklenemedi');
      } finally {
        setLoading(false);
      }
    }

    load();

    return () => {
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [payloadJson]);

  if (loading) {
    return (
      <div style={{ padding: 12, opacity: 0.6, fontSize: 13, fontStyle: 'italic' }}>
        <span style={{ display: 'inline-block', animation: 'spin 1s linear infinite' }}>⏳</span> Medya yükleniyor ve çözülüyor...
      </div>
    );
  }

  if (error || !mediaUrl) {
    return (
      <div style={{ padding: 12, color: '#ef4444', fontSize: 13, border: '1px solid #ef444440', borderRadius: 8, background: '#ef444410' }}>
        ⚠️ {error || 'Hata'}
      </div>
    );
  }

  if (msgType === 'image') {
    return (
      <div style={{ position: 'relative', width: '100%', height: '300px' }}>
        <Image 
          src={mediaUrl} 
          alt="Encrypted Image" 
          fill
          style={{ objectFit: 'contain', borderRadius: 8, cursor: 'pointer' }}
          onClick={() => window.open(mediaUrl, '_blank')}
        />
      </div>
    );
  }

  if (msgType === 'video') {
    return (
      <video 
        src={mediaUrl} 
        controls 
        style={{ maxWidth: '100%', maxHeight: '300px', borderRadius: 8 }}
      />
    );
  }

  if (msgType === 'audio') {
    return (
      <audio 
        src={mediaUrl} 
        controls 
        style={{ maxWidth: '250px' }}
      />
    );
  }

  // Fallback for file
  return (
    <a 
      href={mediaUrl} 
      download="encrypted_file" 
      style={{ display: 'flex', alignItems: 'center', gap: 8, padding: 12, background: 'var(--bg-surface)', borderRadius: 8, textDecoration: 'none', color: 'var(--text-primary)' }}
    >
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 18 15 15"/></svg>
      Dosyayı İndir
    </a>
  );
}
