'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Info } from 'lucide-react';

export default function CookieBanner() {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // Sadece istemci tarafında (tarayıcıda) çalışır.
    const consent = localStorage.getItem('iz_cookie_consent');
    if (!consent) {
      setIsVisible(true);
    }
  }, []);

  const handleAccept = () => {
    localStorage.setItem('iz_cookie_consent', 'accepted');
    setIsVisible(false);
  };

  if (!isVisible) return null;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-[100] p-4 sm:p-6 animate-fade-in translate-y-0">
      <div className="max-w-5xl mx-auto glass shadow-2xl border border-blue-500/30 rounded-2xl p-4 sm:p-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 backdrop-blur-2xl bg-background/60">
        
        <div className="flex items-start gap-4">
          <div className="p-3 bg-blue-500/10 rounded-xl shrink-0 mt-1 sm:mt-0">
            <Info className="w-6 h-6 text-blue-500" />
          </div>
          <div className="space-y-1">
            <h3 className="font-semibold text-foreground text-lg">Gizliliğinize Önem Veriyoruz</h3>
            <p className="text-sm text-muted-foreground leading-relaxed">
              Platformumuzda reklam veya takip amaçlı üçüncü taraf çerezler <strong>kullanılmaz</strong>. 
              Sadece güvenliğinizi sağlamak ve tema/dil gibi temel tercihlerinizi hatırlamak için zorunlu çerezleri kullanıyoruz. 
              Daha fazla bilgi için <a href="/cookies" target="_blank" className="text-blue-500 hover:underline">Çerez Politikamızı</a> ve{' '}
              <a href="/privacy" target="_blank" className="text-blue-500 hover:underline">Gizlilik Politikamızı</a> inceleyebilirsiniz.
            </p>
          </div>
        </div>

        <div className="flex shrink-0 w-full sm:w-auto">
          <Button 
            onClick={handleAccept} 
            className="w-full sm:w-auto px-8 bg-blue-600 hover:bg-blue-700 text-white rounded-xl shadow-lg shadow-blue-500/20 transition-all hover:scale-105"
          >
            Anladım, Kabul Ediyorum
          </Button>
        </div>

      </div>
    </div>
  );
}
