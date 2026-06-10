"use client";

import styles from "./dashboard.module.css";
import { useI18n } from "@/lib/i18n/I18nContext";

export default function DashboardHome() {
  const { t } = useI18n();
  return (
    <div className={styles.container}>
      <h1 className={styles.title}>{t("dashboard.title")}</h1>
      
      <p style={{marginBottom: 20}}>{t("dashboard.welcome")}</p>

      <div className={styles.statsGrid}>
        <div className={styles.statCard}>
          <div className={styles.statLabel}>Total Users</div>
          <div className={styles.statValue}>---</div>
        </div>
        <div className={styles.statCard}>
          <div className={styles.statLabel}>Active Invites</div>
          <div className={styles.statValue}>---</div>
        </div>
      </div>
    </div>
  );
}
