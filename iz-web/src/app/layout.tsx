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
    <html lang={lang}>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body>
        <I18nProvider>
          {children}
        </I18nProvider>
      </body>
    </html>
  );
}
