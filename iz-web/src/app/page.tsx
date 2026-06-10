'use client';
import Link from 'next/link';
import styles from './page.module.css';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useI18n } from '@/lib/i18n/I18nContext';

export default function LandingPage() {
  const { t } = useI18n();

  const features = [
    {
      icon: '🔐',
      title: t('landing.features.signal.title'),
      desc: t('landing.features.signal.desc'),
    },
    {
      icon: '💬',
      title: t('landing.features.instant.title'),
      desc: t('landing.features.instant.desc'),
    },
    {
      icon: '👥',
      title: t('landing.features.groups.title'),
      desc: t('landing.features.groups.desc'),
    },
    {
      icon: '🌐',
      title: t('landing.features.communities.title'),
      desc: t('landing.features.communities.desc'),
    },
    {
      icon: '📞',
      title: t('landing.features.calls.title'),
      desc: t('landing.features.calls.desc'),
    },
    {
      icon: '🕵️',
      title: t('landing.features.blind.title'),
      desc: t('landing.features.blind.desc'),
    },
  ];

  return (
    <main className={styles.landing}>
      {/* Background orbs */}
      <div className={styles.orb1} />
      <div className={styles.orb2} />
      <div className={styles.orb3} />

      {/* Nav */}
      <nav className={styles.nav}>
        <div className={styles.logo}>
          <span className={styles.logoMark}>iz</span>
        </div>
        <div className={styles.navLinks}>
          <LanguageToggle />
          <ThemeToggle />
          <Link href="/login" className={styles.navLink}>{t('landing.login')}</Link>
          <Link href="/register" className={styles.navCta}>{t('landing.start')}</Link>
        </div>
      </nav>

      {/* Hero */}
      <section className={styles.hero}>
        <div className={styles.heroBadge}>
          <span className={styles.badgeDot} />
          <span>{t('landing.encrypted')}</span>
        </div>

        <h1 className={styles.heroTitle}>
          {t('landing.hero_title')}
          <br />
          <span className="gradient-text">{t('landing.hero_subtitle')}</span>
        </h1>

        <p className={styles.heroSubtitle}>
          {t('landing.hero_desc')}
        </p>

        <div className={styles.heroActions}>
          <Link href="/register" className={styles.ctaPrimary} id="get-started-btn">
            {t('landing.cta_start')}
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </Link>
          <Link href="/login" className={styles.ctaSecondary} id="login-btn">
            {t('landing.cta_login')}
          </Link>
        </div>

        {/* Stats */}
        <div className={styles.stats}>
          <div className={styles.stat}>
            <span className={styles.statNum}>E2EE</span>
            <span className={styles.statLabel}>{t('landing.stat_encryption')}</span>
          </div>
          <div className={styles.statDivider} />
          <div className={styles.stat}>
            <span className={styles.statNum}>0</span>
            <span className={styles.statLabel}>{t('landing.stat_access')}</span>
          </div>
          <div className={styles.statDivider} />
          <div className={styles.stat}>
            <span className={styles.statNum}>500K</span>
            <span className={styles.statLabel}>{t('app.communities')}</span>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className={styles.features}>
        {features.map((f, i) => (
          <div key={i} className={styles.featureCard}>
            <div className={styles.featureIcon}>{f.icon}</div>
            <h3 className={styles.featureTitle}>{f.title}</h3>
            <p className={styles.featureDesc}>{f.desc}</p>
          </div>
        ))}
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <span className={styles.footerLogo}>iz</span>
        <span className={styles.footerText}>{t('landing.footer')}</span>
      </footer>
    </main>
  );
}

