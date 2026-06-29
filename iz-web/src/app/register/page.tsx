'use client';
import { useState, FormEvent } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { api, ApiError } from '@/lib/api';
import { generateInitialKeys, prepareRegistrationBundle, storeLocalKeys } from '@/lib/crypto/keys';
import { exportAndUploadBackup } from '@/lib/crypto/backup';
import { saveAuth } from '@/store/auth';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';
import { useI18n } from '@/lib/i18n/I18nContext';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from '@/components/ui/card';
import { Loader2, ArrowRight } from 'lucide-react';

export default function RegisterPage() {
  const router = useRouter();
  const { t } = useI18n();
  const [displayName, setDisplayName] = useState('');
  const [username, setUsername]       = useState('');
  const [email, setEmail]             = useState('');
  const [password, setPassword]       = useState('');
  const [inviteCode, setInviteCode]   = useState('');
  const [error, setError]             = useState('');
  const [loading, setLoading]         = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const keys = generateInitialKeys();
      const bundle = prepareRegistrationBundle(keys);

      await api.auth.register(username.trim(), email.trim(), password, displayName.trim(), inviteCode.trim(), bundle);
      
      const authRes = await api.auth.login(username.trim(), password);
      saveAuth(authRes as any);

      await storeLocalKeys(keys, password);
      await exportAndUploadBackup(password);

      router.push('/app/messages');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t('register.err_registration_failed'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="relative min-h-screen flex items-center justify-center p-4 overflow-hidden">
      {/* Background elements */}
      <div className="absolute inset-0 bg-background" />
      <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] rounded-full bg-blue-500/20 blur-[120px] animate-pulse" style={{ animationDuration: '8s' }} />
      <div className="absolute bottom-[-20%] right-[-10%] w-[60%] h-[60%] rounded-full bg-purple-500/20 blur-[150px] animate-pulse" style={{ animationDuration: '10s' }} />

      <div className="absolute top-6 right-6 flex items-center gap-4 z-20">
        <LanguageToggle />
        <ThemeToggle />
      </div>

      <div className="relative z-10 w-full max-w-md animate-scale-in my-8">
        <div className="flex justify-center mb-8">
          <Link href="/" className="text-4xl font-extrabold tracking-tight gradient-text">
            iz
          </Link>
        </div>

        <Card className="glass glass-interactive shadow-2xl backdrop-blur-2xl transition-all">
          <CardHeader className="text-center space-y-2">
            <CardTitle className="text-2xl">{t('register.title')}</CardTitle>
            <CardDescription>
              {t('register.subtitle')}
            </CardDescription>
          </CardHeader>
          
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="display-name">{t('register.display_name')}</Label>
                <Input
                  id="display-name"
                  type="text"
                  placeholder={t('register.display_name_placeholder')}
                  value={displayName}
                  onChange={e => setDisplayName(e.target.value)}
                  required
                  className="bg-background/50 focus-visible:ring-blue-500 transition-all"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="username">{t('register.username')}</Label>
                <Input
                  id="username"
                  type="text"
                  autoComplete="username"
                  placeholder={t('register.username_placeholder')}
                  value={username}
                  onChange={e => setUsername(e.target.value)}
                  required
                  className="bg-background/50 focus-visible:ring-blue-500 transition-all"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="email">{t('register.email')}</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  placeholder={t('register.email_placeholder')}
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  required
                  className="bg-background/50 focus-visible:ring-blue-500 transition-all"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password">{t('register.password')}</Label>
                <Input
                  id="password"
                  type="password"
                  autoComplete="new-password"
                  placeholder={t('register.password_placeholder')}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  minLength={8}
                  required
                  className="bg-background/50 focus-visible:ring-blue-500 transition-all"
                />
              </div>

              <div className="space-y-2 pt-2 border-t border-border">
                <Label htmlFor="invite-code" className="text-accent">{t('register.invite_code')}</Label>
                <Input
                  id="invite-code"
                  type="text"
                  placeholder={t('register.invite_code_placeholder')}
                  value={inviteCode}
                  onChange={e => setInviteCode(e.target.value)}
                  required
                  className="bg-background/50 border-accent/30 text-foreground placeholder:text-muted-foreground focus-visible:ring-blue-500 transition-all"
                />
              </div>

              {error && (
                <div className="p-3 text-sm text-red-400 bg-red-400/10 border border-red-400/20 rounded-lg">
                  {error}
                </div>
              )}

              <Button type="submit" className="w-full mt-4 bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 transition-all hover:scale-[1.02]" disabled={loading} id="register-submit">
                {loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Kayıt yapılıyor...
                  </>
                ) : (
                  <>
                    {t('register.submit')}
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </>
                )}
              </Button>
            </form>
          </CardContent>
          
          <CardFooter className="flex justify-center border-t border-border pt-6">
            <p className="text-sm text-muted-foreground">
              {t('register.has_account')}{' '}
              <Link href="/login" className="font-medium text-blue-500 hover:text-blue-400 transition-colors">
                {t('register.login')}
              </Link>
            </p>
          </CardFooter>
        </Card>
      </div>
    </div>
  );
}
