import { useI18n } from '@/lib/i18n/I18nContext';
import styles from './ThemeToggle.module.css';

export default function LanguageToggle() {
  const { language, setLanguage } = useI18n();

  return (
    <button
      className={styles.toggle}
      onClick={() => setLanguage(language === 'en' ? 'tr' : 'en')}
      title="Dili Değiştir / Change Language"
    >
      <span className={styles.icon}>
        {language === 'en' ? '🇹🇷' : '🇬🇧'}
      </span>
      <span className={styles.label}>
        {language === 'en' ? 'TR' : 'EN'}
      </span>
    </button>
  );
}
