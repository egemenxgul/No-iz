'use client';
import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import { getAuth, clearAuth } from '@/store/auth';
import { wsManager } from '@/lib/websocket';
import styles from './layout.module.css';

import { useI18n } from '@/lib/i18n/I18nContext';
import CallOverlay from '@/components/CallOverlay';
import ConnectionBanner from '@/components/ConnectionBanner';

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router   = useRouter();
  const pathname = usePathname();
  const { t } = useI18n();
  const [auth, setAuth] = useState(getAuth());
  const [wsStatus, setWsStatus] = useState<'connected' | 'disconnected'>('disconnected');
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const navItems = [
    { href: '/app/messages',    icon: '💬', label: t('app.messages') },
    { href: '/app/groups',      icon: '👥', label: t('app.groups') },
    { href: '/app/communities', icon: '🌐', label: t('app.communities') },
    { href: '/app/calls',       icon: '📞', label: t('app.calls') },
    { href: '/app/settings',    icon: '⚙️', label: t('app.settings') },
  ];

  useEffect(() => {
    const a = getAuth();
    if (!a) { router.replace('/login'); return; }
    setAuth(a);

    // Connect WebSocket
    wsManager.connect();
    const offConn = wsManager.on('__connected',    () => setWsStatus('connected'));
    const offDisc = wsManager.on('__disconnected', () => setWsStatus('disconnected'));

    return () => { offConn(); offDisc(); wsManager.disconnect(); };
  }, [router]);

  function handleLogout() {
    wsManager.disconnect();
    clearAuth();
    router.push('/login');
  }

  if (!auth) return null;

  return (
    <div className={styles.shell}>
      <div className={styles.orb1} />
      <div className={styles.orb2} />

      {/* Mobile Header */}
      <div className={styles.mobileHeader}>
        <span className={styles.logo}>iz</span>
        <button 
          className={styles.mobileMenuBtn} 
          onClick={() => setIsMobileMenuOpen(true)}
          aria-label="Open menu"
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="4" y1="12" x2="20" y2="12"></line>
            <line x1="4" y1="6" x2="20" y2="6"></line>
            <line x1="4" y1="18" x2="20" y2="18"></line>
          </svg>
        </button>
      </div>

      {/* Sidebar Overlay */}
      <div 
        className={`${styles.sidebarOverlay} ${isMobileMenuOpen ? styles.open : ''}`} 
        onClick={() => setIsMobileMenuOpen(false)}
      />
      
      {/* Sidebar */}
      <aside className={`${styles.sidebar} ${isMobileMenuOpen ? styles.open : ''}`}>
        {/* Logo */}
        <div className={styles.sidebarHeader}>
          <span className={styles.logo}>iz</span>
          <div className={styles.wsIndicator} data-status={wsStatus} title={wsStatus === 'connected' ? t('app.ws_connected') : t('app.ws_connecting')} />
        </div>

        {/* Nav */}
        <nav className={styles.nav}>
          {navItems.map(item => (
            <Link
              key={item.href}
              href={item.href}
              className={`${styles.navItem} ${pathname?.startsWith(item.href) ? styles.navItemActive : ''}`}
              id={`nav-${item.href.split('/').pop()}`}
              onClick={() => setIsMobileMenuOpen(false)}
            >
              <span className={styles.navIcon}>{item.icon}</span>
              <span className={styles.navLabel}>{item.label}</span>
            </Link>
          ))}
        </nav>

        {/* User */}
        <div className={styles.sidebarFooter}>
          <div className={styles.userInfo}>
            <div className={styles.userAvatar}>
              {auth.display_name?.[0]?.toUpperCase() ?? auth.username?.[0]?.toUpperCase() ?? '?'}
            </div>
            <div className={styles.userText}>
              <span className={styles.userName}>{auth.display_name || auth.username}</span>
              <span className={styles.userHandle}>@{auth.username}</span>
            </div>
          </div>
          <button onClick={handleLogout} className={styles.logoutBtn} title={t('app.logout')} id="logout-btn">
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M6 14H3a1 1 0 01-1-1V3a1 1 0 011-1h3M10 11l3-3-3-3M13 8H6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className={styles.main}>
        {children}
      </main>

      <CallOverlay />
      <ConnectionBanner />
    </div>
  );
}
