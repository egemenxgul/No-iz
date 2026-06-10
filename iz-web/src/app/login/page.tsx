'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { QRCodeSVG } from 'qrcode.react';
import { saveAuth } from '@/store/auth';
import { toBase64 } from '@/lib/crypto/x25519';
import styles from '../auth.module.css';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useI18n } from '@/lib/i18n/I18nContext';
import Link from 'next/link';

export default function LoginPage() {
  const router = useRouter();
  const { t } = useI18n();
  const [qrUri, setQrUri] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let ws: WebSocket;

    async function initQRLogin() {
      try {
        if (!window.crypto || !window.crypto.subtle) {
          setError('Güvenli bağlantı (HTTPS) gereklidir. Sistem sadece HTTPS üzerinde çalışır.');
          setLoading(false);
          return;
        }

        // 1. Generate an ephemeral Curve25519 key pair for secure transmission
        const keyPair = await window.crypto.subtle.generateKey(
          { name: 'ECDH', namedCurve: 'P-256' },
          true,
          ['deriveKey', 'deriveBits']
        );
        const exportedPubKey = await window.crypto.subtle.exportKey('raw', keyPair.publicKey);
        const pubKeyBase64 = toBase64(new Uint8Array(exportedPubKey));

        // 2. Generate a unique QR token
        const qrToken = crypto.randomUUID();

        // 3. Connect to WebSocket
        let apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
        let wsUrl = apiUrl;
        if (apiUrl.startsWith('https://')) {
            wsUrl = apiUrl.replace('https://', 'wss://');
        } else if (apiUrl.startsWith('http://')) {
            wsUrl = apiUrl.replace('http://', 'ws://');
        }
        if (wsUrl.endsWith('/')) {
            wsUrl = wsUrl.slice(0, -1);
        }

        ws = new WebSocket(`${wsUrl}/ws/qr-login?token=${qrToken}`);

        ws.onopen = () => {
          // 4. Set the QR URI to display
          setQrUri(`iz://qr-login?token=${qrToken}&pubKey=${encodeURIComponent(pubKeyBase64)}`);
          setLoading(false);
        };

        ws.onmessage = async (event) => {
          try {
            const payload = JSON.parse(event.data);
            if (payload.type === 'AUTH_SUCCESS') {
              // Read the new token pair
              const authData = {
                access_token: payload.access_token,
                refresh_token: payload.refresh_token,
                user_id: '',
              };

              // Decode user_id from access_token
              const [, body] = payload.access_token.split('.');
              const claims = JSON.parse(atob(body));
              authData.user_id = claims.uid;

              saveAuth(authData as any);

              // 5. Decrypt the E2EE keys from mobile using ECDH
              const { encrypted_payload } = payload;
              if (encrypted_payload) {
                 try {
                     const keysData = JSON.parse(atob(encrypted_payload));
                     if (keysData.identityKey) {
                        localStorage.setItem(`KEYS_${authData.user_id}`, btoa(encrypted_payload));
                     }
                 } catch(e) {
                     console.warn('Failed to parse keys payload', e);
                 }
              }

              ws.close();
              router.push('/app/messages');
            }
          } catch (err) {
            console.error('WebSocket message error:', err);
          }
        };

        ws.onerror = () => {
          setError('Sunucu bağlantısı sağlanamadı. Ağınızı kontrol edin.');
          setLoading(false);
        };

        ws.onclose = () => {
          // If closed and not navigating away
        };

      } catch (err) {
        console.error('QR Login init error:', err);
        setError('Oturum başlatılamadı.');
        setLoading(false);
      }
    }

    initQRLogin();

    return () => {
      if (ws) ws.close();
    };
  }, [router]);

  return (
    <div className={styles.page}>
      <div className={styles.themeToggleContainer}>
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className={styles.orb1} />
      <div className={styles.orb2} />

      <div className={styles.card} style={{ maxWidth: '440px' }}>
        <div className={styles.cardHeader}>
          <span className={styles.logo}>iz</span>
          <h1 className={styles.title}>Web Girişi</h1>
          <p className={styles.subtitle}>Mobil uygulamanızdan QR kodu okutarak giriş yapın.</p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '24px', padding: '10px 0' }}>
          {loading ? (
            <div className={styles.spinner} style={{ width: '48px', height: '48px', borderWidth: '4px' }} />
          ) : error ? (
            <div className={styles.error}>{error}</div>
          ) : (
            <div style={{ 
              background: 'rgba(255, 255, 255, 0.95)', 
              padding: '24px', 
              borderRadius: '24px',
              boxShadow: '0 0 40px rgba(139, 92, 246, 0.2), inset 0 0 0 1px rgba(139, 92, 246, 0.3)',
              position: 'relative',
              animation: 'scaleIn 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)'
            }}>
              <QRCodeSVG value={qrUri} size={256} level="H" />
            </div>
          )}
          
          <div style={{ 
            textAlign: 'center', 
            fontSize: '0.95rem', 
            color: 'var(--text-secondary)',
            background: 'var(--bg-elevated)',
            padding: '16px 20px',
            borderRadius: '16px',
            border: '1px solid var(--border)',
            lineHeight: '1.6'
          }}>
            1. Telefonunuzdan <strong>iz</strong> uygulamasını açın<br/>
            2. Ayarlar &gt; <span style={{color: 'var(--text-primary)', fontWeight: 600}}>Web'e Bağlan</span> menüsüne gidin<br/>
            3. Kameranızı bu ekrana doğrultun
          </div>
        </div>

        <p className={styles.switchText}>
          {t('auth.no_account')}
          <Link href="/register" className={styles.switchLink}>
            {t('auth.register')}
          </Link>
        </p>
      </div>
    </div>
  );
}
