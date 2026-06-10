"use client";

import { useState } from "react";
import { fetchApi, deleteCookie } from "@/lib/api";
import { useRouter } from "next/navigation";
import styles from "./settings.module.css";

export default function SettingsPage() {
  const router = useRouter();
  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState("");
  const [error, setError] = useState("");

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setSuccess("");

    if (newPassword !== confirmPassword) {
      setError("New passwords do not match.");
      return;
    }
    if (newPassword.length < 8) {
      setError("New password must be at least 8 characters.");
      return;
    }

    setLoading(true);
    try {
      await fetchApi("/api/auth/change-password", {
        method: "POST",
        body: JSON.stringify({
          old_password: oldPassword,
          new_password: newPassword,
        }),
      });
      setSuccess("Password changed successfully! Please log in again.");
      setOldPassword("");
      setNewPassword("");
      setConfirmPassword("");

      // Force re-login
      setTimeout(() => {
        deleteCookie("token");
        router.push("/");
      }, 2000);
    } catch (err: any) {
      setError(err.message || "Failed to change password.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h1 className={styles.title}>Settings</h1>
        <p className={styles.subtitle}>Manage your admin account</p>
      </div>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>Change Password</h2>

        {error && <div className={styles.error}>{error}</div>}
        {success && <div className={styles.successMsg}>{success}</div>}

        <form className={styles.form} onSubmit={handleChangePassword}>
          <div className={styles.inputGroup}>
            <label className={styles.label}>Current Password</label>
            <input
              type="password"
              className={styles.input}
              placeholder="Your current password"
              value={oldPassword}
              onChange={(e) => setOldPassword(e.target.value)}
              required
            />
          </div>
          <div className={styles.inputGroup}>
            <label className={styles.label}>New Password</label>
            <input
              type="password"
              className={styles.input}
              placeholder="At least 8 characters"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              required
            />
          </div>
          <div className={styles.inputGroup}>
            <label className={styles.label}>Confirm New Password</label>
            <input
              type="password"
              className={styles.input}
              placeholder="Repeat new password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              required
            />
          </div>
          <button type="submit" className={styles.button} disabled={loading}>
            {loading ? "Updating..." : "Update Password"}
          </button>
        </form>
      </div>
    </div>
  );
}
