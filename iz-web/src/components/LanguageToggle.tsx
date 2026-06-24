import { useI18n } from '@/lib/i18n/I18nContext';
import styles from './ThemeToggle.module.css';

export default function LanguageToggle() {
  const { language, setLanguage } = useI18n();

  const handleNextLanguage = () => {
    const nextLang = language === 'en' ? 'tr' : language === 'tr' ? 'de' : 'en';
    setLanguage(nextLang);
  };

  const getFlag = (lang: string) => {
    switch(lang) {
      case 'tr': return '🇹🇷';
      case 'de': return '🇩🇪';
      default: return '🇬🇧';
    }
  };

  return (
    <button
      className={styles.toggle}
      onClick={handleNextLanguage}
      title="Change Language / Dili Değiştir / Sprache ändern"
    >
      <span className={styles.icon}>
        {getFlag(language)}
      </span>
      <span className={styles.label}>
        {language.toUpperCase()}
      </span>
    </button>
  );
}
