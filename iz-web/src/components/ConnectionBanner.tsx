'use client';
import { useConnectionStatus } from '@/hooks/useConnectionStatus';
import styles from './ConnectionBanner.module.css';
import { useI18n } from '@/lib/i18n/I18nContext';

export default function ConnectionBanner() {
  const status = useConnectionStatus();
  const { t } = useI18n();

  if (status === 'connected') return null;

  return (
    <div className={`${styles.banner} ${styles[status]}`} role="alert" aria-live="polite">
      <div className={styles.indicator}>
        <span className={styles.dot} />
      </div>
      <span className={styles.text}>
        {status === 'reconnecting'
          ? (t('app.ws_connecting') || 'Yeniden bağlanıyor...')
          : (t('app.offline') || 'Çevrimdışı')}
      </span>
      {status === 'reconnecting' && (
        <svg className={styles.spinner} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M12 2v4m0 12v4M4.93 4.93l2.83 2.83m8.48 8.48 2.83 2.83M2 12h4m12 0h4M4.93 19.07l2.83-2.83m8.48-8.48 2.83-2.83"/>
        </svg>
      )}
    </div>
  );
}
