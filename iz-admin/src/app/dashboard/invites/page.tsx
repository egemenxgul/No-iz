"use client";

import { useState, useEffect } from "react";
import styles from "./invites.module.css";
import { fetchApi } from "@/lib/api";

type InviteCode = {
  id: string;
  code: string;
  max_uses: number;
  use_count: number;
  is_active: boolean;
  expires_at: string | null;
  created_at: string;
};

export default function InvitesPage() {
  const [codes, setCodes] = useState<InviteCode[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [newCode, setNewCode] = useState("");
  const [maxUses, setMaxUses] = useState(1);
  const [creating, setCreating] = useState(false);

  const loadCodes = async () => {
    try {
      setLoading(true);
      const data = await fetchApi("/api/invites/admin");
      setCodes(data.codes || []);
    } catch (err: any) {
      setError(err.message || "Failed to load invites");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCodes();
  }, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setCreating(true);
    setError("");

    try {
      await fetchApi("/api/invites/admin", {
        method: "POST",
        body: JSON.stringify({
          code: newCode.trim() || undefined, // empty uses random generated
          max_uses: maxUses,
        }),
      });
      setNewCode("");
      setMaxUses(1);
      loadCodes();
    } catch (err: any) {
      setError(err.message || "Failed to create code");
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h1 className={styles.title}>Invite Codes</h1>
        <p className={styles.subtitle}>Manage platform access codes</p>
      </div>

      {error && <div className={styles.error}>{error}</div>}

      <div className={styles.createCard}>
        <h2 className={styles.cardTitle}>Create New Code</h2>
        <form className={styles.form} onSubmit={handleCreate}>
          <div className={styles.inputGroup}>
            <label className={styles.label}>Custom Code (Optional)</label>
            <input
              type="text"
              className={styles.input}
              placeholder="e.g. EARLYACCESS"
              value={newCode}
              onChange={(e) => setNewCode(e.target.value.toUpperCase())}
            />
          </div>
          
          <div className={styles.inputGroup}>
            <label className={styles.label}>Max Uses</label>
            <input
              type="number"
              className={styles.input}
              min="0"
              value={maxUses}
              onChange={(e) => setMaxUses(parseInt(e.target.value) || 0)}
              title="0 for unlimited"
            />
          </div>

          <button type="submit" className={styles.button} disabled={creating}>
            {creating ? "Creating..." : "Generate"}
          </button>
        </form>
      </div>

      <div className={styles.listCard}>
        <h2 className={styles.cardTitle}>Active Codes</h2>
        {loading ? (
          <p>Loading...</p>
        ) : (
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Code</th>
                <th>Uses</th>
                <th>Status</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {codes.length === 0 ? (
                <tr>
                  <td colSpan={4} style={{ textAlign: "center", padding: "2rem" }}>
                    No invite codes found
                  </td>
                </tr>
              ) : (
                codes.map((c) => (
                  <tr key={c.id}>
                    <td><span className={styles.codeBadge}>{c.code}</span></td>
                    <td>
                      {c.use_count} / {c.max_uses === 0 ? "∞" : c.max_uses}
                    </td>
                    <td>
                      {c.is_active ? (
                        <span className={styles.statusActive}>Active</span>
                      ) : (
                        <span className={styles.statusInactive}>Inactive</span>
                      )}
                    </td>
                    <td>{new Date(c.created_at).toLocaleDateString()}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
