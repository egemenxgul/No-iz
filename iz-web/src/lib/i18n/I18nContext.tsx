'use client';

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import en from './locales/en.json';
import tr from './locales/tr.json';
import de from './locales/de.json';

type Language = 'en' | 'tr' | 'de';

interface I18nContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
  t: (key: string) => string;
}

const I18nContext = createContext<I18nContextType | undefined>(undefined);

const dictionaries = { en, tr, de };

interface TranslationDict {
  [key: string]: string | TranslationDict | undefined;
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>('en');
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const storedLang = localStorage.getItem('iz_language') as Language;
    if (storedLang && (storedLang === 'en' || storedLang === 'tr' || storedLang === 'de')) {
      setLanguageState(storedLang);
      document.cookie = `iz_language=${storedLang};path=/;max-age=31536000`;
      document.documentElement.lang = storedLang;
    } else {
      // Auto detect from browser
      const browserLang = navigator.language.slice(0, 2).toLowerCase();
      let detected: Language = 'en';
      if (browserLang === 'tr') detected = 'tr';
      if (browserLang === 'de') detected = 'de';
      setLanguageState(detected);
      localStorage.setItem('iz_language', detected);
      document.cookie = `iz_language=${detected};path=/;max-age=31536000`;
      document.documentElement.lang = detected;
    }
    setMounted(true);
  }, []);

  const setLanguage = (lang: Language) => {
    setLanguageState(lang);
    localStorage.setItem('iz_language', lang);
    document.cookie = `iz_language=${lang};path=/;max-age=31536000`;
    document.documentElement.lang = lang;
  };

  const t = (path: string): string => {
    const keys = path.split('.');
    let current = dictionaries[language] as unknown as TranslationDict;

    for (const key of keys) {
      if (current[key] === undefined) {
        // Fallback to English if translation is missing
        let fallback = dictionaries['en'] as unknown as TranslationDict;
        for (const k of keys) {
          if (fallback[k] === undefined) return path;
          fallback = fallback[k] as TranslationDict;
        }
        return fallback as unknown as string;
      }
      current = current[key] as TranslationDict;
    }

    return current as unknown as string;
  };

  // Prevent hydration mismatch by not rendering anything until mounted
  if (!mounted) {
    return null;
  }

  return (
    <I18nContext.Provider value={{ language, setLanguage, t }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  const context = useContext(I18nContext);
  if (context === undefined) {
    throw new Error('useI18n must be used within an I18nProvider');
  }
  return context;
}
