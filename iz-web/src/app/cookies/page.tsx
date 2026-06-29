import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';

export default function CookiePolicyPage() {
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
          <h1 className="text-4xl font-extrabold tracking-tight mb-4 gradient-text">Çerez Politikası</h1>
          <p className="text-sm text-muted-foreground mb-12">Son Güncelleme: 30 Haziran 2026</p>

          <div className="space-y-8 text-base leading-relaxed text-muted-foreground">
            
            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">1. Çerez (Cookie) Nedir?</h2>
              <p>
                Çerezler, bir web sitesini ziyaret ettiğinizde tarayıcınız aracılığıyla bilgisayarınıza veya mobil cihazınıza kaydedilen küçük metin dosyalarıdır. Çerezler, web sitesinin daha verimli çalışmasını sağlamak, kullanıcı deneyimini kişiselleştirmek ve sistem güvenliğini artırmak amacıyla yaygın olarak kullanılmaktadır.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">2. iz Platformu Çerezleri Nasıl Kullanır?</h2>
              <p className="mb-4">
                Platformumuz, gizlilik odaklı bir felsefeyle tasarlandığından, reklam veya üçüncü taraf takip (tracking) çerezleri kesinlikle kullanılmaz. Yalnızca aşağıdaki amaçlara yönelik, "Zorunlu ve İşlevsel Çerezler" (Essential Cookies) kullanılmaktadır:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Oturum Yönetimi:</strong> Hesabınıza giriş yaptığınızda oturumunuzun aktif kalmasını sağlamak ve yetkisiz erişimleri engellemek için geçici oturum çerezleri kullanılır.</li>
                <li><strong>Kullanıcı Tercihleri:</strong> Dil seçimi (örneğin Türkçe veya İngilizce) ve tema tercihleri (Karanlık veya Aydınlık mod) gibi arayüz seçimlerinizin cihazınızda hatırlanması için kullanılır. (Örn: `iz_language` çerezi veya `localStorage` içindeki `theme` anahtarı).</li>
                <li><strong>GDPR Onayı:</strong> Çerez politikamızı onaylayıp onaylamadığınızı hatırlamak ve size aynı uyarıyı sürekli göstermemek için kullanılır. (Örn: `iz_cookie_consent`).</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">3. Üçüncü Taraf Çerezleri</h2>
              <p>
                Platformumuz üzerinde Google Analytics, Meta Pixel veya benzeri harici takip ve reklam araçlarına ait hiçbir kod parçacığı bulunmaz. Bu nedenle cihazınıza üçüncü taraflar tarafından izleme veya profil oluşturma amaçlı çerez yerleştirilmesi mümkün değildir.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">4. Çerezleri Nasıl Yönetebilir ve Silebilirsiniz?</h2>
              <p>
                Tarayıcınızın ayarlarını değiştirerek çerezleri dilediğiniz zaman silebilir veya tüm web siteleri için çerez kullanımını tamamen engelleyebilirsiniz. Ancak unutmayınız ki, "Zorunlu Çerezler"in engellenmesi durumunda iz Platformu'na giriş yapamayabilir veya bazı temel işlevleri kullanamayabilirsiniz. Çerez yönetimi hakkında daha fazla bilgi için tarayıcınızın "Yardım" veya "Ayarlar" menüsüne başvurabilirsiniz.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">5. Daha Fazla Bilgi</h2>
              <p>
                Çerez kullanımımız hakkında sorularınız varsa veya haklarınızı kullanmak istiyorsanız, Gizlilik Politikamızı inceleyebilir ya da bizimle <strong>privacy@no-iz.app</strong> adresi üzerinden iletişime geçebilirsiniz.
              </p>
            </section>

          </div>
        </div>
      </main>
    </div>
  );
}
