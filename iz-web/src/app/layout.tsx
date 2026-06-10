import type { Metadata } from 'next';
import { cookies } from 'next/headers';
import './globals.css';

export const metadata: Metadata = {
  title: 'iz — Stay Hidden',
  description: 'End-to-end encrypted messaging, groups and communities platform.',
  keywords: ['messaging', 'encrypted', 'privacy', 'security', 'iz'],
  openGraph: {
    title: 'iz — Stay Hidden',
    description: 'End-to-end encrypted messaging, groups and communities platform.',
    type: 'website',
    url: 'https://no-iz.app',
  },
  icons: {
    icon: '/favicon.ico',
  },
};

import { I18nProvider } from '@/lib/i18n/I18nContext';

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const cookieStore = await cookies();
  const lang = cookieStore.get('iz_language')?.value || 'en';

  return (
    <html lang={lang} suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet" />
        <script dangerouslySetInnerHTML={{
          __html: `
            (function() {
              try {
                var theme = localStorage.getItem('theme');
                if (theme === 'dark' || theme === 'light') {
                  document.documentElement.setAttribute('data-theme', theme);
                } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
                  document.documentElement.setAttribute('data-theme', 'light');
                } else {
                  document.documentElement.setAttribute('data-theme', 'dark');
                }
              } catch (e) {}
            })();
          `
        }} />
      </head>
      <body>
        <I18nProvider>
          {children}
        </I18nProvider>
      </body>
    </html>
  );
}
