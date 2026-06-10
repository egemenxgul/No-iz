'use client';
import styles from '../messages/empty.module.css';
import { useI18n } from '@/lib/i18n/I18nContext';
export default function GroupsPage() {
  const { t } = useI18n();
  return (
    <div className={styles.empty}>
      <div className={styles.emptyIcon}>👥</div>
      <h2 className={styles.emptyTitle}>{t('app.groups')}</h2>
      <p className={styles.emptyText}>{t('app.loading')}</p>
    </div>
  );
}
