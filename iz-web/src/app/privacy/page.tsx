import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';

export default function PrivacyPolicyPage() {
  return (
    <div className="relative min-h-screen bg-background text-foreground overflow-hidden">
      {/* Background Orbs */}
      <div className="fixed top-[-10%] left-[-10%] w-[40%] h-[40%] rounded-full bg-blue-500/10 blur-[120px] pointer-events-none" />
      <div className="fixed bottom-[-10%] right-[-5%] w-[50%] h-[50%] rounded-full bg-purple-500/10 blur-[150px] pointer-events-none" />

      {/* Header */}
      <header className="relative z-10 w-full p-6 max-w-5xl mx-auto flex items-center justify-between">
        <Link href="/" className="inline-flex items-center text-sm font-medium text-muted-foreground hover:text-foreground transition-colors group">
          <ArrowLeft className="w-4 h-4 mr-2 group-hover:-translate-x-1 transition-transform" />
          Ana Sayfaya Dön
        </Link>
        <div className="flex items-center gap-4">
          <LanguageToggle />
          <ThemeToggle />
        </div>
      </header>

      {/* Content */}
      <main className="relative z-10 max-w-3xl mx-auto px-6 py-12 pb-24">
        <div className="glass p-8 md:p-12 rounded-3xl border border-border shadow-2xl">
          <h1 className="text-4xl font-extrabold tracking-tight mb-4 gradient-text">Gizlilik Politikası</h1>
          <p className="text-sm text-muted-foreground mb-12">Son Güncelleme: 30 Haziran 2026</p>

          <div className="space-y-8 text-base leading-relaxed text-muted-foreground">
            
            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">1. Giriş</h2>
              <p>
                iz Platformu olarak gizliliğinize en üst düzeyde önem veriyoruz. Misyonumuz, kullanıcıların iletişim verilerini uçtan uca şifreleyerek kimsenin (biz dahil) erişemeyeceği güvenli bir ortam sunmaktır. Bu Gizlilik Politikası, hangi verileri nasıl topladığımızı, neden işlediğimizi ve gizliliğinizi nasıl koruduğumuzu açıklamaktadır.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">2. Veri Şifreleme ve Sıfır Bilgi Prensibi</h2>
              <p className="mb-4">
                Platform üzerinde gönderilen tüm mesajlar, aramalar, medya dosyaları ve gruplara ait iletişim verileri uçtan uca şifrelenir (E2EE). 
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Sıfır Bilgi:</strong> Şifreleme anahtarlarınız cihazınızda oluşturulur ve cihazınızda kalır. Sunucularımızda şifre çözme anahtarlarınız hiçbir zaman düz metin olarak saklanmaz.</li>
                <li><strong>İçerik Gizliliği:</strong> Sunucularımız üzerinden geçen veriler sadece şifreli veri paketlerinden ibarettir. Gönderdiğiniz fotoğraf, video veya metin içerikleri bizim tarafımızdan okunamaz, taranamaz veya analiz edilemez.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">3. Hangi Verileri Topluyoruz?</h2>
              <p className="mb-4">Hizmetlerimizi sunabilmek için minimum düzeyde veri topluyoruz:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Hesap Bilgileri:</strong> Kayıt sırasında alınan rastgele veya anonim kullanıcı adı (username). İsteğe bağlı olarak e-posta adresi (hesap kurtarma amacıyla).</li>
                <li><strong>Bağlantı Metadata'sı:</strong> Sistem güvenliğini sağlamak ve DDoS saldırılarını önlemek amacıyla anlık IP adresiniz ağ geçitlerinde geçici olarak tutulabilir ancak kalıcı loglanmaz. Kimin kiminle iletişim kurduğu (sosyal ağ grafiği) şifreli olarak saklanır ve tarafımızca analiz edilemez.</li>
                <li><strong>Cihaz ve İstemci Bilgisi:</strong> Anlık bildirim (Push Notification) iletimi için cihazınıza özel anonim bildirim jetonları (token).</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">4. Verilerin Kullanım Amacı</h2>
              <p>
                Topladığımız sınırlı sayıdaki veriler, yalnızca hesabınızın çalışmasını sağlamak, anlık bildirimleri iletebilmek, spam ve sistem suistimallerini engellemek ve yasal mevzuat gerekliliklerini (varsa, sadece yasal ve teknik sınırlar dahilinde) yerine getirmek amacıyla kullanılır. Verileriniz kesinlikle reklam, pazarlama veya ticari analiz amaçlarıyla üçüncü taraflara satılamaz.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">5. Veri Paylaşımı</h2>
              <p>
                iz Platformu, "Okuyamadığımızı paylaşamayız" ilkesiyle hareket eder. Şifrelenmiş içeriklerinize erişimimiz olmadığı için, bu içeriklerin yasal mercilerle dahi paylaşılması teknik olarak imkansızdır. Paylaşılabilecek tek bilgi (yasal bir mahkeme kararı durumunda) hesabınızın oluşturulma tarihi veya varsa kayıtlı e-posta adresiniz gibi anonim/temel verilerdir.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">6. Kullanıcı Hakları (GDPR Uyumluluğu)</h2>
              <p className="mb-4">
                Avrupa Birliği Genel Veri Koruma Tüzüğü (GDPR) ve diğer uluslararası standartlar gereği aşağıdaki haklara sahipsiniz:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Hesap verilerinize erişme ve bunları dışa aktarma hakkı.</li>
                <li>Yanlış bilgilerin düzeltilmesini talep etme hakkı.</li>
                <li><strong>Unutulma Hakkı:</strong> Hesabınızı sildiğinizde, sunucularımızdaki size ait tüm şifreli içerikler ve hesap bilgileri kalıcı olarak yok edilir. Yedeklerden silinmesi en fazla 30 gün sürebilir.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">7. İletişim</h2>
              <p>
                Gizlilik politikamız veya veri işleme süreçlerimiz hakkında sorularınız için bizimle <strong>privacy@no-iz.app</strong> adresi üzerinden iletişime geçebilirsiniz.
              </p>
            </section>

          </div>
        </div>
      </main>
    </div>
  );
}
