import Link from 'next/link';
import { ArrowLeft, LifeBuoy, ShieldCheck, KeyRound, Cloud, PhoneCall } from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';

export default function HelpCenterPage() {
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
          <div className="flex items-center gap-4 mb-4">
            <div className="w-12 h-12 rounded-2xl bg-blue-500/20 flex items-center justify-center border border-blue-500/30 text-blue-500">
              <LifeBuoy className="w-6 h-6" />
            </div>
            <h1 className="text-4xl font-extrabold tracking-tight gradient-text">Yardım Merkezi</h1>
          </div>
          <p className="text-sm text-muted-foreground mb-12">Sıkça Sorulan Sorular ve Platform Rehberi</p>

          <div className="space-y-8 text-base leading-relaxed text-muted-foreground">
            
            <section className="bg-muted/30 p-6 rounded-2xl border border-border/50 hover:border-border transition-colors">
              <h2 className="text-xl font-bold text-foreground mb-4 flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-green-500" />
                Sıfır Bilgi (Zero-Knowledge) nedir?
              </h2>
              <p>
                iz Platformu "Sıfır Bilgi" prensibiyle çalışır. Bu, mesajlarınızın cihazınızdan çıkmadan önce şifrelendiği ve sadece alıcının cihazında çözülebildiği anlamına gelir. Biz, iz ekibi olarak, veya herhangi bir üçüncü şahıs bu mesajların içeriğini asla göremez. Şifreleme anahtarlarınız cihazınızda kalır ve sunucularımıza gitmez.
              </p>
            </section>

            <section className="bg-muted/30 p-6 rounded-2xl border border-border/50 hover:border-border transition-colors">
              <h2 className="text-xl font-bold text-foreground mb-4 flex items-center gap-2">
                <KeyRound className="w-5 h-5 text-orange-500" />
                Parolasız (Passkeys) giriş nasıl çalışır?
              </h2>
              <p>
                Platforma kayıt olurken veya giriş yaparken geleneksel bir şifre (örn: 123456) oluşturmazsınız. Bunun yerine cihazınızın donanımsal güvenliğini (Face ID, Touch ID, Windows Hello) kullanarak biyometrik bir Passkey oluşturursunuz. Bu sayede şifrenizin çalınması veya tahmin edilmesi imkansız hale gelir.
              </p>
            </section>

            <section className="bg-muted/30 p-6 rounded-2xl border border-border/50 hover:border-border transition-colors">
              <h2 className="text-xl font-bold text-foreground mb-4 flex items-center gap-2">
                <Cloud className="w-5 h-5 text-blue-500" />
                Mesajlarımı nasıl yedeklerim?
              </h2>
              <p>
                Uygulama ayarlarından "Bulut Yedekleme" özelliğini açtığınızda, tüm sohbet geçmişiniz cihazınızda şifrelenir ve iz Platformu'nun kendi güvenli sunucularına şifreli bir blok olarak aktarılır. Yeni bir cihaza geçtiğinizde, aynı Passkey ile giriş yaparak bu şifreli yedeği cihazınıza indirebilir ve yalnızca kendi cihazınızda şifresini çözerek sohbetlerinizi kurtarabilirsiniz.
              </p>
            </section>

            <section className="bg-muted/30 p-6 rounded-2xl border border-border/50 hover:border-border transition-colors">
              <h2 className="text-xl font-bold text-foreground mb-4 flex items-center gap-2">
                <PhoneCall className="w-5 h-5 text-purple-500" />
                Aramalarım dinlenebilir mi?
              </h2>
              <p>
                Hayır. Sesli ve görüntülü aramalarınız WebRTC altyapısıyla doğrudan uçtan uca (P2P - Peer-to-Peer) kurulur ve DTLS-SRTP ile kriptografik olarak kilitlenir. Ses ve görüntü verileriniz sunucularımız üzerinden şifresiz olarak geçmediği için dinlenmesi veya kaydedilmesi teknik olarak mümkün değildir.
              </p>
            </section>

            <section className="bg-muted/30 p-6 rounded-2xl border border-border/50 hover:border-border transition-colors">
              <h2 className="text-xl font-bold text-foreground mb-4">Daha fazla desteğe mi ihtiyacınız var?</h2>
              <p>
                Hesabınızla ilgili diğer tüm sorunlar, güvenlik bildirimleri veya teknik destek için bize doğrudan <strong>support@no-iz.app</strong> adresinden ulaşabilirsiniz.
              </p>
            </section>

          </div>
        </div>
      </main>
    </div>
  );
}
