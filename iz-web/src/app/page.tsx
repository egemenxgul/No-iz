'use client';

import Link from 'next/link';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useI18n } from '@/lib/i18n/I18nContext';
import { Button } from '@/components/ui/button';
import { Shield, MessageCircle, Users, Globe, Phone, EyeOff, ArrowRight } from 'lucide-react';

export default function LandingPage() {
  const { t } = useI18n();

  const features = [
    {
      icon: <Shield className="w-6 h-6 text-indigo-400" />,
      title: t('landing.features.signal.title'),
      desc: t('landing.features.signal.desc'),
    },
    {
      icon: <MessageCircle className="w-6 h-6 text-blue-400" />,
      title: t('landing.features.instant.title'),
      desc: t('landing.features.instant.desc'),
    },
    {
      icon: <Users className="w-6 h-6 text-purple-400" />,
      title: t('landing.features.groups.title'),
      desc: t('landing.features.groups.desc'),
    },
    {
      icon: <Globe className="w-6 h-6 text-pink-400" />,
      title: t('landing.features.communities.title'),
      desc: t('landing.features.communities.desc'),
    },
    {
      icon: <Phone className="w-6 h-6 text-green-400" />,
      title: t('landing.features.calls.title'),
      desc: t('landing.features.calls.desc'),
    },
    {
      icon: <EyeOff className="w-6 h-6 text-red-400" />,
      title: t('landing.features.blind.title'),
      desc: t('landing.features.blind.desc'),
    },
  ];

  return (
    <main className="relative min-h-screen overflow-hidden flex flex-col">
      {/* Background Orbs */}
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] rounded-full bg-blue-600/20 blur-[120px] pointer-events-none animate-pulse" style={{ animationDuration: '8s' }} />
      <div className="absolute bottom-[-10%] right-[-5%] w-[50%] h-[50%] rounded-full bg-purple-600/20 blur-[150px] pointer-events-none animate-pulse" style={{ animationDuration: '10s' }} />
      <div className="absolute top-[30%] left-[60%] w-[30%] h-[30%] rounded-full bg-indigo-500/10 blur-[100px] pointer-events-none" />

      {/* Navigation */}
      <nav className="relative z-10 flex items-center justify-between px-6 py-4 md:px-12 md:py-6 max-w-7xl mx-auto w-full">
        <div className="flex items-center gap-2">
          <span className="text-3xl font-extrabold tracking-tight text-transparent bg-clip-text bg-gradient-to-br from-blue-700 to-blue-400">iz</span>
        </div>
        <div className="flex items-center gap-4">
          <LanguageToggle />
          <ThemeToggle />
          <div className="hidden sm:flex items-center gap-4">
            <Link href="/login" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
              {t('landing.login')}
            </Link>
            <Button asChild className="rounded-full bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/25 transition-all">
              <Link href="/register">{t('landing.start')}</Link>
            </Button>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative z-10 flex flex-col items-center justify-center text-center px-4 pt-20 pb-32 flex-1">
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full glass border border-border mb-8 animate-fade-in">
          <span className="flex w-2 h-2 rounded-full bg-green-500 animate-pulse" />
          <span className="text-sm font-medium text-muted-foreground">{t('landing.encrypted')}</span>
        </div>

        <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight max-w-4xl animate-fade-in [animation-delay:100ms] opacity-0" style={{ animationFillMode: 'forwards' }}>
          {t('landing.hero_title')}
          <br className="hidden sm:block" />
          <span className="gradient-text">
            {t('landing.hero_subtitle')}
          </span>
        </h1>

        <p className="mt-6 text-lg md:text-xl text-muted-foreground max-w-2xl animate-fade-in [animation-delay:200ms] opacity-0" style={{ animationFillMode: 'forwards' }}>
          {t('landing.hero_desc')}
        </p>

        <div className="mt-10 flex flex-col sm:flex-row items-center gap-4 animate-fade-in [animation-delay:300ms] opacity-0" style={{ animationFillMode: 'forwards' }}>
          <Button asChild size="lg" className="rounded-full px-8 bg-blue-600 hover:bg-blue-700 text-white shadow-xl shadow-blue-500/30 transition-all hover:scale-105 group">
            <Link href="/register">
              {t('landing.cta_start')}
              <ArrowRight className="ml-2 w-4 h-4 group-hover:translate-x-1 transition-transform" />
            </Link>
          </Button>
          <Button asChild size="lg" variant="outline" className="rounded-full px-8 glass hover:bg-muted border-border transition-all">
            <Link href="/login">
              {t('landing.cta_login')}
            </Link>
          </Button>
        </div>

        {/* Stats Section */}
        <div className="mt-20 flex flex-col sm:flex-row items-center justify-center sm:justify-around w-full max-w-3xl gap-8 animate-fade-in [animation-delay:400ms] opacity-0" style={{ animationFillMode: 'forwards' }}>
          <div className="flex flex-col items-center gap-2">
            <span className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-br from-green-400 to-emerald-600">E2EE</span>
            <span className="text-sm text-muted-foreground font-medium">{t('landing.stat_encryption')}</span>
          </div>
          <div className="hidden sm:block w-[1px] h-12 bg-border mx-auto" />
          <div className="flex flex-col items-center gap-2">
            <span className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-br from-orange-400 to-red-500">0</span>
            <span className="text-sm text-muted-foreground font-medium">{t('landing.stat_access')}</span>
          </div>
          <div className="hidden sm:block w-[1px] h-12 bg-border mx-auto" />
          <div className="flex flex-col items-center gap-2">
            <span className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-br from-blue-400 to-purple-500">500K</span>
            <span className="text-sm text-muted-foreground font-medium">{t('app.communities')}</span>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="relative z-10 max-w-7xl mx-auto px-6 py-24 w-full">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, i) => (
            <div 
              key={i} 
              className="glass glass-interactive p-8 rounded-3xl flex flex-col gap-4 animate-fade-in opacity-0"
              style={{ animationDelay: `\${500 + i * 100}ms`, animationFillMode: 'forwards' }}
            >
              <div className="w-12 h-12 rounded-2xl bg-muted flex items-center justify-center border border-border">
                {feature.icon}
              </div>
              <h3 className="text-xl font-semibold text-foreground">{feature.title}</h3>
              <p className="text-muted-foreground leading-relaxed">
                {feature.desc}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* Footer */}
      <footer className="relative z-10 border-t border-border/40 mt-auto">
        <div className="max-w-7xl mx-auto px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <span className="text-2xl font-extrabold text-transparent bg-clip-text bg-gradient-to-br from-blue-700 to-blue-400">iz</span>
          <div className="flex flex-col sm:flex-row items-center gap-4 sm:gap-8">
            <div className="flex items-center gap-4 text-sm text-muted-foreground">
              <Link href="/terms" className="hover:text-foreground transition-colors">Kullanım Şartları</Link>
              <Link href="/privacy" className="hover:text-foreground transition-colors">Gizlilik Politikası</Link>
              <Link href="/cookies" className="hover:text-foreground transition-colors">Çerez Politikası</Link>
              <Link href="/help" className="hover:text-foreground transition-colors">Yardım Merkezi</Link>
            </div>
            <span className="text-sm text-muted-foreground">{t('landing.footer')}</span>
          </div>
        </div>
      </footer>
    </main>
  );
}
