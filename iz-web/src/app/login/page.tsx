'use client';
import { useState, FormEvent } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api, ApiError } from '@/lib/api';
import { saveAuth } from '@/store/auth';
import { decryptLocalKeys } from '@/lib/crypto/keys';
import styles from '../auth.module.css';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useI18n } from '@/lib/i18n/I18nContext';

export default function LoginPage() {
  const router = useRouter();
  const { t } = useI18n();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError]       = useState('');
  const [loading, setLoading]   = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await api.auth.login(username.trim(), password);
      
      // Decrypt and verify local keys (if available on this device)
      void decryptLocalKeys(password).then(keys => {
        if (!keys) console.warn('Could not retrieve local E2EE keys on this device');
      });

      saveAuth({ ...data, access_token: data.access_token });
      router.push('/app/messages');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t('login.err_login_failed'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className={styles.page}>
      <div className={styles.themeToggleContainer} style={{ display: 'flex', gap: '8px' }}>
        <LanguageToggle />
        <ThemeToggle />
      </div>
      <div className={styles.orb1} />
      <div className={styles.orb2} />

      <div className={styles.card}>
        <div className={styles.cardHeader}>
          <span className={styles.logo}>iz</span>
          <h1 className={styles.title}>{t('login.title')}</h1>
          <p className={styles.subtitle}>{t('login.subtitle')}</p>
        </div>

        <form onSubmit={handleSubmit} className={styles.form}>
          <div className={styles.field}>
            <label className={styles.label} htmlFor="username">{t('login.email_or_username')}</label>
            <input
              id="username"
              type="text"
              autoComplete="username"
              className={styles.input}
              value={username}
              onChange={e => setUsername(e.target.value)}
              placeholder={t('login.email_or_username_placeholder')}
              required
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="password">{t('login.password')}</label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              className={styles.input}
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder={t('login.password_placeholder')}
              required
            />
          </div>

          {error && <div className={styles.error}>{error}</div>}

          <button type="submit" className={styles.submitBtn} disabled={loading} id="login-submit">
            {loading ? <span className={styles.spinner} /> : t('login.submit')}
          </button>
        </form>

        <p className={styles.switchText}>
          {t('login.no_account')}{' '}
          <Link href="/register" className={styles.switchLink}>{t('login.register')}</Link>
        </p>
      </div>
    </div>
  );
}
