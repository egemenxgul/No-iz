import { AuthTokens } from '@/types';

const TOKEN_KEY = 'iz_auth';

// Secure cookie helper functions
function setCookie(name: string, value: string, days = 7) {
  if (typeof document === 'undefined') return;
  const date = new Date();
  date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
  const encodedValue = encodeURIComponent(value);
  document.cookie = `${name}=${encodedValue};expires=${date.toUTCString()};path=/;Secure;SameSite=Lax`;
}

function getCookie(name: string): string | null {
  if (typeof document === 'undefined') return null;
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) {
    const raw = parts.pop()?.split(';').shift();
    return raw ? decodeURIComponent(raw) : null;
  }
  return null;
}

function deleteCookie(name: string) {
  if (typeof document === 'undefined') return;
  document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;Secure;SameSite=Lax`;
}

export function saveAuth(tokens: AuthTokens) {
  if (typeof window === 'undefined') return;
  setCookie(TOKEN_KEY, JSON.stringify(tokens));
}

export function getAuth(): AuthTokens | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = getCookie(TOKEN_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function getToken(): string | null {
  return getAuth()?.access_token ?? null;
}

export function clearAuth() {
  if (typeof window === 'undefined') return;
  deleteCookie(TOKEN_KEY);
}

export function isAuthenticated(): boolean {
  return !!getToken();
}

