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
                iz Platformu olarak gizliliğinize en üst düzeyde önem veriyoruz. Misyonumuz, kullanıcıların iletişim verilerini uçtan uca şifreleyerek kimsenin (biz dahil) erişemeyeceği güvenli bir ortam sunmaktır. Bu Gizlilik Politikası, hangi verileri nasıl topladığımızı, cihazınızdaki verilerin nasıl korunduğunu ve bulut yedekleme süreçlerini detaylandırmaktadır.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">2. Uçtan Uca Şifreleme (E2EE) ve Sıfır Bilgi</h2>
              <p className="mb-4">
                Platform üzerinde gönderilen tüm mesajlar, medya dosyaları ve grup iletişim verileri Double Ratchet ve X3DH protokolleri kullanılarak uçtan uca şifrelenir. 
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Sıfır Bilgi:</strong> Şifreleme anahtarlarınız yalnızca cihazınızda oluşturulur. Sunucularımızda şifre çözme anahtarlarınız asla tutulmaz.</li>
                <li><strong>Yerel Şifreleme (SQLCipher):</strong> Telefonunuzdaki mesaj geçmişiniz ve veritabanınız (iz_vault.db), cihazınıza özel AES-256 şifrelemesi ile kilitlenir. Uygulama kapalıyken cihazınıza fiziksel erişim sağlansa bile verileriniz okunamaz.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">3. Sesli ve Görüntülü Aramalar (WebRTC)</h2>
              <p>
                Sesli ve görüntülü aramalarınız WebRTC altyapısı kullanılarak tamamen eşler arası (P2P - Peer-to-Peer) olarak gerçekleşir. Aramalar DTLS-SRTP protokolleriyle uçtan uca şifrelenir. Bu sayede ses ve görüntü verileriniz hiçbir zaman sunucularımız üzerinden şifresiz olarak geçmez ve kaydedilemez.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">4. Güvenli Bulut Yedekleme (Cloud Backup)</h2>
              <p className="mb-4">
                Yeni bir cihaza geçtiğinizde veya uygulamayı sildiğinizde verilerinizi kaybetmemeniz için uçtan uca şifrelenmiş Bulut Yedekleme hizmeti sunuyoruz. Bu yedekleme işlemi tamamen iz Platformu'nun kendi güvenli bulut sunucularında gerçekleşir:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Sunucu Tarafı Şifreli Saklama:</strong> Tüm sohbet geçmişiniz cihazınızda kendi şifreleme anahtarlarınızla şifrelenir ve iz Platformu sunucularına yalnızca şifreli bir metin yığını olarak gönderilir.</li>
                <li><strong>Kusursuz İzolasyon:</strong> Yedekler sunucumuzda barındırılsa dahi şifre çözme anahtarı yalnızca sizin cihazınızda olduğu için, bizim veya herhangi bir siber saldırganın sunucudaki mesaj arşivinize ulaşıp içeriğini okuması kriptografik olarak imkansızdır.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">5. Hangi Verileri Topluyoruz?</h2>
              <p className="mb-4">Hizmetlerimizi sunabilmek için minimum düzeyde veri topluyoruz:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Kimlik Doğrulama:</strong> Parolasız giriş (Passkeys) teknolojisi ile şifrenizi sunucuya göndermeden biyometrik doğrulama kullanıyoruz. Kayıt sırasında sadece anonim bir kullanıcı adı alınır.</li>
                <li><strong>Anlık Bildirimler (Push):</strong> Firebase/APNs üzerinden cihazınıza mesaj geldiğini bildirmek için anonim cihaz jetonları (token) kullanılır. Bildirim içerikleri (mesaj metni) sunucudan "boş yük (blank payload)" olarak gider, mesajın içeriği cihazınızda yerel olarak çözülüp bildirime yazılır.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">6. Veri Paylaşımı ve Yasal Süreçler</h2>
              <p>
                iz Platformu, "Okuyamadığımızı paylaşamayız" ilkesiyle hareket eder. Şifrelenmiş içeriklerinize, yerel veritabanınıza veya kişisel bulut yedeklerinize erişimimiz olmadığı için, bu içeriklerin yasal mercilerle dahi paylaşılması kriptografik olarak imkansızdır. Paylaşılabilecek tek bilgi (mahkeme kararı durumunda) hesabınızın oluşturulma tarihi gibi temel metadatalardır.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">7. Kullanıcı Hakları ve Unutulma Hakkı</h2>
              <p className="mb-4">
                Avrupa Birliği Genel Veri Koruma Tüzüğü (GDPR) gereği aşağıdaki haklara sahipsiniz:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Hesap verilerinize erişme ve bunları dışa aktarma hakkı.</li>
                <li><strong>Unutulma Hakkı:</strong> Hesabınızı sildiğinizde, sunucularımızdaki size ait tüm şifreli anahtarlar, jetonlar ve veriler kalıcı olarak yok edilir. Buluttaki (Drive/iCloud) yedeklerinizi silmek sizin sorumluluğunuzdadır.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">8. İletişim</h2>
              <p>
                Gizlilik politikamız, şifreleme altyapımız veya veri işleme süreçlerimiz hakkında detaylı teknik sorularınız için bizimle <strong>privacy@no-iz.app</strong> adresi üzerinden iletişime geçebilirsiniz.
              </p>
            </section>

          </div>
        </div>
      </main>
    </div>
  );
}
