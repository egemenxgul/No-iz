'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { Community } from '@/types';
import styles from './communities.module.css';
import { useI18n } from '@/lib/i18n/I18nContext';

export default function CommunitiesPage() {
  const { t, language } = useI18n();
  const [communities, setCommunities] = useState<Community[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<'mine' | 'discover'>('mine');

  useEffect(() => {
    setLoading(true);
    const fetch = tab === 'mine' ? api.communities.mine() : api.communities.discover();
    fetch
      .then(r => setCommunities(r.communities ?? []))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [tab]);

  return (
    <div className={styles.page}>
      <div className={styles.header}>
        <h1 className={styles.title}>{t('app.communities')}</h1>
        <div className={styles.tabs}>
          <button className={`${styles.tab} ${tab === 'mine' ? styles.tabActive : ''}`} onClick={() => setTab('mine')}>
            {t('app.messages')}
          </button>
          <button className={`${styles.tab} ${tab === 'discover' ? styles.tabActive : ''}`} onClick={() => setTab('discover')}>
            {t('app.explore')}
          </button>
        </div>
      </div>

      <div className={styles.list}>
        {loading && Array.from({length: 4}).map((_, i) => (
          <div key={i} className={`${styles.card} skeleton`} style={{height: 80}} />
        ))}
        {!loading && communities.length === 0 && (
          <div className={styles.empty}>
            <span className={styles.emptyIcon}>🌐</span>
            <p>{tab === 'mine' ? t('app.not_joined_community') : t('app.no_communities')}</p>
          </div>
        )}
        {communities.map(c => (
          <Link key={c.id} href={`/app/communities/${c.slug}`} className={styles.card}>
            <div className={styles.cardAvatar}>{c.name[0]?.toUpperCase()}</div>
            <div className={styles.cardBody}>
              <span className={styles.cardName}>{c.name}</span>
              <span className={styles.cardMeta}>
                {c.member_count?.toLocaleString(language)} {t('app.members')}
                {c.is_public ? ` · ${t('app.public')}` : ` · ${t('app.private')}`}
              </span>
            </div>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className={styles.cardArrow}>
              <path d="M5 3l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </Link>
        ))}
      </div>
    </div>
  );
}

