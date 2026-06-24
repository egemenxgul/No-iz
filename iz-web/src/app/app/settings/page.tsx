'use client';
import Link from 'next/link';
import { useI18n } from '@/lib/i18n/I18nContext';
import styles from './settings.module.css';

export default function SettingsPage() {
  const { t } = useI18n();
  return (
    <div className={styles.container}>
      <h2 className={styles.title}>{t('app.settings')}</h2>
      
      <div className={styles.menu}>
        <Link href="/app/settings/backup" className={styles.menuItem}>
          <div className={styles.icon}>☁️</div>
          <div className={styles.content}>
            <div className={styles.menuTitle}>{t('settings.backup_menu_title')}</div>
            <div className={styles.menuDesc}>{t('settings.backup_menu_desc')}</div>
          </div>
          <div className={styles.chevron}>›</div>
        </Link>
        
        {/* Placeholder for other settings */}
        <div className={styles.menuItem} style={{ opacity: 0.5 }}>
          <div className={styles.icon}>🔒</div>
          <div className={styles.content}>
            <div className={styles.menuTitle}>{t('settings.privacy')}</div>
            <div className={styles.menuDesc}>{t('app.coming_soon')}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
