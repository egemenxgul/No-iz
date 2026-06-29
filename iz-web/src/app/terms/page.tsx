import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';

export default function TermsOfServicePage() {
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
          <h1 className="text-4xl font-extrabold tracking-tight mb-4 gradient-text">Kullanım Şartları</h1>
          <p className="text-sm text-muted-foreground mb-12">Son Güncelleme: 30 Haziran 2026</p>

          <div className="space-y-8 text-base leading-relaxed text-muted-foreground">
            
            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">1. Taraflar ve Kapsam</h2>
              <p>
                Bu Kullanım Şartları ("Sözleşme"), iz Platformu ("Platform", "Biz", "Bize" veya "Bizi") ile Platformu ziyaret eden, erişen veya hizmetlerinden yararlanan her türlü gerçek veya tüzel kişi ("Kullanıcı", "Siz") arasında akdedilmiştir. Platformumuza erişerek, bu Sözleşme'nin tüm hükümlerini eksiksiz olarak okuduğunuzu, anladığınızı ve kabul ettiğinizi beyan etmektesiniz.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">2. Hizmetin Niteliği</h2>
              <p className="mb-4">
                iz Platformu, uçtan uca şifreleme (End-to-End Encryption - E2EE) teknolojisini temel alan güvenli bir anlık mesajlaşma, sesli/görüntülü görüşme ve topluluk oluşturma platformudur. Hizmetlerimizin temel felsefesi "Sıfır Bilgi" (Zero-Knowledge) prensibine dayanır. Bu prensip gereği;
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>İçerikleriniz (mesajlar, medya dosyaları, ses kayıtları) yalnızca sizin ve iletişim kurduğunuz cihazlar tarafından çözülebilir.</li>
                <li>Biz dahil olmak üzere hiçbir üçüncü taraf şifrelenmiş içeriklere erişemez veya bunları okuyamaz.</li>
                <li>Platform, şifreleme anahtarlarınızı sunucularında saklamaz.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">3. Kullanıcı Yükümlülükleri</h2>
              <p className="mb-4">Kullanıcı, Platformu kullanırken aşağıdaki kurallara riayet edeceğini kabul eder:</p>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Yasalara Uyum:</strong> Platform üzerinden gerçekleştirilen her türlü iletişim, Türkiye Cumhuriyeti yasalarına, Kullanıcı'nın bulunduğu ülkenin yerel yasalarına ve uluslararası hukuka uygun olmalıdır.</li>
                <li><strong>Hesap Güvenliği:</strong> E2EE mimarisi gereği, hesabınıza erişim için kullanılan şifre ve cihazların güvenliği tamamen Kullanıcı'nın sorumluluğundadır. Şifrenin kaybedilmesi durumunda, verilerin kurtarılamayacağı Kullanıcı tarafından peşinen kabul edilir.</li>
                <li><strong>Kabul Edilebilir Kullanım:</strong> Platform; zararlı yazılım (malware) dağıtmak, kimlik avı (phishing) yapmak, taciz veya nefret söyleminde bulunmak, telif hakkı ihlali yapmak veya herhangi bir yasa dışı faaliyeti organize etmek amacıyla kullanılamaz.</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">4. Fikri Mülkiyet Hakları</h2>
              <p>
                Platform'da yer alan yazılım kodları, arayüz tasarımları, logolar, grafikler ve diğer tüm materyallerin fikri mülkiyet hakları iz Platformu'na aittir. Kullanıcı, Platform'u yalnızca kişisel veya kurum içi iletişim amacıyla kullanma hakkına (sınırlı lisans) sahiptir. Kaynak kodlarının kopyalanması, değiştirilmesi veya ticari amaçla dağıtılması kesinlikle yasaktır.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">5. Sorumlulukların Sınırlandırılması</h2>
              <p>
                Platform "olduğu gibi" (as is) esasıyla sunulmaktadır. Kesintisiz erişim veya hatasız çalışma garantisi verilmemektedir. iz Platformu, donanım arızaları, ağ sorunları, Kullanıcı'nın kendi güvenlik ihmalleri (cihazının hacklenmesi vb.) veya mücbir sebeplerden doğabilecek veri kayıplarından, iletişim kesintilerinden ve maddi/manevi zararlardan doğrudan veya dolaylı olarak sorumlu tutulamaz.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">6. Hesabın Kapatılması ve Fesih</h2>
              <p>
                Kullanıcı dilediği zaman Platform üzerindeki hesabını silebilir. iz Platformu, bu Sözleşme hükümlerinin veya yasal mevzuatın ihlal edildiğine kanaat getirdiği durumlarda, önceden haber vermeksizin Kullanıcı hesabını askıya alma veya kalıcı olarak silme hakkını saklı tutar.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">7. Değişiklikler</h2>
              <p>
                Biz, işbu Sözleşme şartlarını dilediğimiz zaman önceden bildirimde bulunmaksızın değiştirme hakkını saklı tutarız. Yapılan güncellemeler, bu sayfada yayımlandığı andan itibaren geçerlilik kazanır. Kullanıcıların periyodik olarak bu sayfayı kontrol etmeleri kendi sorumluluğundadır.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-foreground mb-4">8. İletişim</h2>
              <p>
                Bu şartlar hakkında sorularınız, yasal talepleriniz veya güvenlik bildirimleriniz için bizimle <strong>legal@no-iz.app</strong> adresi üzerinden şifrelenmiş veya açık metin olarak iletişime geçebilirsiniz.
              </p>
            </section>

          </div>
        </div>
      </main>
    </div>
  );
}
