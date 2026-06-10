"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import styles from "./page.module.css";
import { fetchApi, setCookie } from "@/lib/api";
import { useI18n } from "@/lib/i18n/I18nContext";

export default function LoginPage() {
  const router = useRouter();
  const { t, language, setLanguage } = useI18n();
  const [emailOrUsername, setEmailOrUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const data = await fetchApi("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({ 
          email_or_username: emailOrUsername, 
          password 
        }),
      });

      setCookie("token", data.access_token);
      router.push("/dashboard");
    } catch (err: any) {
      setError(err.message || t("login.err_login_failed"));
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className={styles.main}>
      <button 
        onClick={() => setLanguage(language === 'en' ? 'tr' : 'en')}
        style={{ position: 'absolute', top: 20, right: 20, background: 'none', border: 'none', cursor: 'pointer', fontSize: 24 }}
        title="Dili Değiştir / Change Language"
      >
        {language === 'en' ? '🇹🇷' : '🇬🇧'}
      </button>

      <div className={styles.loginCard}>
        <div className={styles.header}>
          <h1 className={styles.logo}>iz.</h1>
          <p className={styles.subtitle}>{t("login.title")}</p>
        </div>

        {error && <div className={styles.error}>{error}</div>}

        <form className={styles.form} onSubmit={handleLogin}>
          <div className={styles.inputGroup}>
            <label htmlFor="email" className={styles.label}>
              {t("login.email_or_username")}
            </label>
            <input
              type="text"
              id="email"
              className={styles.input}
              placeholder={t("login.email_or_username_placeholder")}
              value={emailOrUsername}
              onChange={(e) => setEmailOrUsername(e.target.value)}
              required
            />
          </div>

          <div className={styles.inputGroup}>
            <label htmlFor="password" className={styles.label}>
              {t("login.password")}
            </label>
            <input
              type="password"
              id="password"
              className={styles.input}
              placeholder={t("login.password_placeholder")}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <button type="submit" className={styles.button} disabled={loading}>
            {loading ? t("login.submitting") : t("login.submit")}
          </button>
        </form>
      </div>
    </main>
  );
}

