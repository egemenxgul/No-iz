'use client';
import { usePathname } from 'next/navigation';
import Link from 'next/link';

export default function HelpLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  const navItems = [
    { name: 'Sıkça Sorulan Sorular', path: '/help/faq' },
    { name: 'Markdown Kullanımı', path: '/help/markdown' },
  ];

  return (
    <div style={{ maxWidth: 1000, margin: '0 auto', padding: '40px 20px', display: 'flex', gap: '30px' }}>
      {/* Sidebar Navigation */}
      <div style={{ width: '250px', flexShrink: 0 }}>
        <h2 style={{ fontSize: '20px', fontWeight: 'bold', marginBottom: '20px', paddingLeft: '10px' }}>Yardım Merkezi</h2>
        <nav style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {navItems.map((item) => {
            const isActive = pathname === item.path;
            return (
              <Link key={item.path} href={item.path}>
                <div style={{
                  padding: '10px 15px',
                  borderRadius: '8px',
                  backgroundColor: isActive ? 'var(--accent)' : 'transparent',
                  color: isActive ? '#fff' : 'var(--text-secondary)',
                  fontWeight: isActive ? '600' : '400',
                  transition: 'background-color 0.2s, color 0.2s',
                  cursor: 'pointer'
                }}>
                  {item.name}
                </div>
              </Link>
            );
          })}
        </nav>
      </div>

      {/* Main Content Area */}
      <div style={{ flex: 1, minWidth: 0, paddingLeft: '20px', borderLeft: '1px solid var(--border)' }}>
        {children}
      </div>
    </div>
  );
}
