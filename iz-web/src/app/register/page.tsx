'use client';
import { useState, FormEvent } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api, ApiError } from '@/lib/api';
import { saveAuth } from '@/store/auth';
import { generateInitialKeys, storeLocalKeys, prepareRegistrationBundle } from '@/lib/crypto/keys';
import styles from '../auth.module.css';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useI18n } from '@/lib/i18n/I18nContext';

export default function RegisterPage() {
  const router = useRouter();
  const { t } = useI18n();
  const [displayName, setDisplayName] = useState('');
  const [username, setUsername]       = useState('');
  const [email, setEmail]             = useState('');
  const [password, setPassword]       = useState('');
  const [inviteCode, setInviteCode]   = useState('');
  const [error, setError]             = useState('');
  const [loading, setLoading]         = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const keys = generateInitialKeys();
      const bundle = prepareRegistrationBundle(keys);

      const data = await api.auth.register(username.trim(), email.trim(), password, displayName.trim(), inviteCode.trim(), bundle);
      
      await storeLocalKeys(keys, password);
      saveAuth({ ...data, access_token: data.access_token });
      
      router.push('/app/messages');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t('register.err_registration_failed'));
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
          <h1 className={styles.title}>{t('register.title')}</h1>
          <p className={styles.subtitle}>{t('register.subtitle')}</p>
        </div>

        <form onSubmit={handleSubmit} className={styles.form}>
          <div className={styles.field}>
            <label className={styles.label} htmlFor="display-name">{t('register.display_name')}</label>
            <input
              id="display-name"
              type="text"
              className={styles.input}
              value={displayName}
              onChange={e => setDisplayName(e.target.value)}
              placeholder={t('register.display_name_placeholder')}
              required
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="username">{t('register.username')}</label>
            <input
              id="username"
              type="text"
              autoComplete="username"
              className={styles.input}
              value={username}
              onChange={e => setUsername(e.target.value)}
              placeholder={t('register.username_placeholder')}
              required
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="email">{t('register.email')}</label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              className={styles.input}
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder={t('register.email_placeholder')}
              required
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="password">{t('register.password')}</label>
            <input
              id="password"
              type="password"
              autoComplete="new-password"
              className={styles.input}
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder={t('register.password_placeholder')}
              minLength={8}
              required
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="invite-code">
              {t('register.invite_code')}
            </label>
            <input
              id="invite-code"
              type="text"
              className={`${styles.input} ${styles.inputAccent}`}
              value={inviteCode}
              onChange={e => setInviteCode(e.target.value)}
              placeholder={t('register.invite_code_placeholder')}
              required
            />
          </div>

          {error && <div className={styles.error}>{error}</div>}

          <button type="submit" className={styles.submitBtn} disabled={loading} id="register-submit">
            {loading ? <span className={styles.spinner} /> : t('register.submit')}
          </button>
        </form>

        <p className={styles.switchText}>
          {t('register.has_account')}{' '}
          <Link href="/login" className={styles.switchLink}>{t('register.login')}</Link>
        </p>
      </div>
    </div>
  );
}
