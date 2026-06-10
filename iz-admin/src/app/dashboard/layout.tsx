"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import styles from "./layout.module.css";
import { deleteCookie } from "@/lib/api";
import { useI18n } from "@/lib/i18n/I18nContext";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const { t } = useI18n();

  const handleLogout = () => {
    deleteCookie("token");
    router.push("/");
  };

  return (
    <div className={styles.container}>
      <aside className={styles.sidebar}>
        <div className={styles.logoContainer}>
          <h1 className={styles.logo}>iz.</h1>
          <span className={styles.badge}>Admin</span>
        </div>

        <nav className={styles.nav}>
          <Link href="/dashboard" className={styles.navLink}>
            {t("dashboard.nav.overview")}
          </Link>
          <Link href="/dashboard/invites" className={styles.navLink}>
            {t("dashboard.nav.invites")}
          </Link>
          <Link href="/dashboard/users" className={styles.navLink}>
            {t("dashboard.nav.users")}
          </Link>
          <Link href="/dashboard/settings" className={styles.navLink}>
            {t("dashboard.nav.settings")}
          </Link>
        </nav>

        <div className={styles.footer}>
          <button className={styles.logoutButton} onClick={handleLogout}>
            {t("dashboard.nav.sign_out")}
          </button>
        </div>
      </aside>

      <main className={styles.mainContent}>
        <header className={styles.header}>
          <div className={styles.headerTitle}>{t("dashboard.nav.overview")}</div>
          <div className={styles.adminProfile}>{t("dashboard.profile")}</div>
        </header>
        <div className={styles.content}>{children}</div>
      </main>
    </div>
  );
}
