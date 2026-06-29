'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { QRCodeSVG } from 'qrcode.react';
import { saveAuth } from '@/store/auth';
import { deviceSyncManager } from '@/lib/device-sync';
import { toBase64, generateKeyPair } from '@/lib/crypto/x25519';
import { decryptQrPayload } from '@/lib/crypto/aes-gcm';
import { api, ApiError } from '@/lib/api';
import { downloadAndRestoreBackup } from '@/lib/crypto/backup';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import Link from 'next/link';
import { useI18n } from '@/lib/i18n/I18nContext';
import { Loader2, QrCode, KeyRound, ArrowRight } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from '@/components/ui/card';

export default function LoginPage() {
  const router = useRouter();
  const { t } = useI18n();
  const [qrUri, setQrUri] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitLoading, setIsSubmitLoading] = useState(false);

  useEffect(() => {
    let isPolling = false;
    let pollTimeout: NodeJS.Timeout;

    async function initQRLogin() {
      try {
        if (!window.crypto) {
          setError('Kriptografik işlemler desteklenmiyor.');
          setLoading(false);
          return;
        }

        const keyPair = generateKeyPair();
        const pubKeyBase64 = toBase64(keyPair.publicKey);
        localStorage.setItem('qr_login_private_key', toBase64(keyPair.privateKey));

        const qrToken = crypto.randomUUID();
        setQrUri(`iz://qr-login?token=${qrToken}&pubKey=${encodeURIComponent(pubKeyBase64)}`);
        setLoading(false);

        let apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
        if (typeof window !== 'undefined' && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')) {
            apiUrl = 'http://localhost:8080';
        }
        if (apiUrl.endsWith('/')) {
            apiUrl = apiUrl.slice(0, -1);
        }

        isPolling = true;

        const poll = async () => {
          if (!isPolling) return;
          try {
            const res = await fetch(`${apiUrl}/api/auth/qr-poll?token=${qrToken}`);
            if (res.status === 200) {
              const payload = await res.json();
              if (payload.type === 'AUTH_SUCCESS') {
                isPolling = false;
                
                const authData = {
                  access_token: payload.access_token,
                  refresh_token: payload.refresh_token,
                  user_id: '',
                };

                const [, body] = payload.access_token.split('.');
                const claims = JSON.parse(atob(body));
                authData.user_id = claims.uid;

                saveAuth(authData as any);

                const { encrypted_payload } = payload;
                if (encrypted_payload) {
                   try {
                       const privKey = localStorage.getItem('qr_login_private_key');
                       let keysData;
                       
                       if (privKey) {
                           try {
                               const decryptedStr = await decryptQrPayload(encrypted_payload, privKey);
                               keysData = JSON.parse(decryptedStr);
                           } catch (ecdhError) {
                               console.warn('ECDH decryption failed, falling back to legacy mode:', ecdhError);
                               keysData = JSON.parse(atob(encrypted_payload));
                           }
                       } else {
                           keysData = JSON.parse(atob(encrypted_payload));
                       }

                       if (keysData && keysData.identityKey) {
                          localStorage.setItem(`KEYS_${authData.user_id}`, btoa(JSON.stringify(keysData)));
                       }
                   } catch(e) {
                       console.warn('Failed to parse keys payload', e);
                   }
                }
                
                try {
                   await deviceSyncManager.startSync();
                } catch(e) {
                   console.error('Failed to start device sync', e);
                }

                router.push('/app/messages');
                return;
              }
            }
          } catch (err) {
            console.error('QR poll error:', err);
          }

          if (isPolling) {
            pollTimeout = setTimeout(poll, 2000);
          }
        };

        poll();

        setTimeout(() => {
          if (isPolling) {
            isPolling = false;
            initQRLogin();
          }
        }, 60000);

      } catch (err) {
        console.error('QR Login init error:', err);
        setError('Oturum başlatılamadı.');
        setLoading(false);
      }
    }

    initQRLogin();

    return () => {
      isPolling = false;
      if (pollTimeout) clearTimeout(pollTimeout);
    };
  }, [router]);

  async function handlePasswordLogin(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setIsSubmitLoading(true);
    try {
      const authRes = await api.auth.login(username.trim(), password);
      saveAuth(authRes as any);

      try {
        await downloadAndRestoreBackup(password);
      } catch (backupErr: any) {
        console.warn('Backup restore failed or no backup found:', backupErr);
      }

      router.push('/app/messages');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Giriş yapılamadı.');
    } finally {
      setIsSubmitLoading(false);
    }
  }

  return (
    <div className="relative min-h-screen flex items-center justify-center p-4 overflow-hidden">
      {/* Background elements */}
      <div className="absolute inset-0 bg-background" />
      <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-500/20 blur-[120px]" />
      <div className="absolute bottom-[-20%] right-[-10%] w-[60%] h-[60%] rounded-full bg-purple-500/20 blur-[150px]" />

      <div className="absolute top-6 right-6 flex items-center gap-4 z-20">
        <LanguageToggle />
        <ThemeToggle />
      </div>

      <div className="relative z-10 w-full max-w-md animate-scale-in">
        <div className="flex justify-center mb-8">
          <Link href="/" className="text-4xl font-extrabold tracking-tight text-transparent bg-clip-text bg-gradient-to-br from-indigo-400 to-purple-400">
            iz
          </Link>
        </div>

        <Card className="glass shadow-2xl backdrop-blur-2xl">
          <CardHeader className="text-center space-y-2">
            <CardTitle className="text-2xl">Giriş Yap</CardTitle>
            <CardDescription>
              Web sürümüne güvenle bağlanın
            </CardDescription>
          </CardHeader>
          
          <CardContent>
            <Tabs defaultValue="password" className="w-full">
              <TabsList className="grid w-full grid-cols-2 mb-6 bg-background/50 border border-border">
                <TabsTrigger value="password" className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground transition-all">
                  <KeyRound className="w-4 h-4 mr-2" />
                  Şifre
                </TabsTrigger>
                <TabsTrigger value="qr" className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground transition-all">
                  <QrCode className="w-4 h-4 mr-2" />
                  QR Kod
                </TabsTrigger>
              </TabsList>

              <TabsContent value="password">
                <form onSubmit={handlePasswordLogin} className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="username">Kullanıcı Adı veya E-posta</Label>
                    <Input
                      id="username"
                      type="text"
                      autoComplete="username"
                      placeholder="ornek_kullanici"
                      value={username}
                      onChange={e => setUsername(e.target.value)}
                      required
                      className="bg-background/50 focus-visible:ring-indigo-500"
                    />
                  </div>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <Label htmlFor="password">Şifre</Label>
                      <Link href="/forgot-password" className="text-sm font-medium text-indigo-400 hover:text-indigo-300">
                        Şifremi Unuttum
                      </Link>
                    </div>
                    <Input
                      id="password"
                      type="password"
                      autoComplete="current-password"
                      placeholder="••••••••"
                      value={password}
                      onChange={e => setPassword(e.target.value)}
                      required
                      className="bg-background/50 focus-visible:ring-indigo-500"
                    />
                  </div>

                  {error && (
                    <div className="p-3 text-sm text-red-400 bg-red-400/10 border border-red-400/20 rounded-lg">
                      {error}
                    </div>
                  )}

                  <Button type="submit" className="w-full bg-indigo-600 hover:bg-indigo-700 text-white" disabled={isSubmitLoading}>
                    {isSubmitLoading ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Giriş yapılıyor...
                      </>
                    ) : (
                      <>
                        Giriş Yap
                        <ArrowRight className="ml-2 h-4 w-4" />
                      </>
                    )}
                  </Button>
                </form>
              </TabsContent>

              <TabsContent value="qr" className="flex flex-col items-center py-4">
                {loading ? (
                  <div className="flex items-center justify-center h-64">
                    <Loader2 className="h-8 w-8 animate-spin text-indigo-500" />
                  </div>
                ) : error ? (
                  <div className="p-4 text-sm text-red-400 bg-red-400/10 border border-red-400/20 rounded-lg w-full text-center">
                    {error}
                  </div>
                ) : (
                  <div className="flex flex-col items-center gap-6 w-full animate-fade-in">
                    <div className="p-4 bg-white rounded-2xl shadow-xl border border-border">
                      <QRCodeSVG value={qrUri} size={220} level="H" />
                    </div>
                    
                    <div className="w-full p-4 rounded-xl bg-background/40 border border-border text-sm text-muted-foreground leading-relaxed">
                      <ol className="list-decimal list-inside space-y-1">
                        <li>Telefonunuzdan <strong>iz</strong> uygulamasını açın</li>
                        <li>Ayarlar {'>'} <strong className="text-foreground">Web&apos;e Bağlan</strong> menüsüne gidin</li>
                        <li>Kameranızı bu ekrana doğrultun</li>
                      </ol>
                    </div>
                  </div>
                )}
              </TabsContent>
            </Tabs>
          </CardContent>
          
          <CardFooter className="flex justify-center border-t border-border pt-6">
            <p className="text-sm text-muted-foreground">
              Hesabınız yok mu?{' '}
              <Link href="/register" className="font-medium text-indigo-400 hover:text-indigo-300 transition-colors">
                Kayıt Ol
              </Link>
            </p>
          </CardFooter>
        </Card>
      </div>
    </div>
  );
}
