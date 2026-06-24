'use client';

import React, { useState, useRef } from 'react';
import styles from './Backup.module.css';
import { exportAndUploadBackup, exportToFile, downloadAndRestoreBackup, importFromFile } from '@/lib/crypto/backup';

// Inline SVG icons — no external package needed
const FiDownloadCloud = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="8 17 12 21 16 17"/><line x1="12" y1="12" x2="12" y2="21"/><path d="M20.88 18.09A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.29"/></svg>;
const FiUploadCloud = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="16 16 12 12 8 16"/><line x1="12" y1="12" x2="12" y2="21"/><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/></svg>;
const FiDownload = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>;
const FiUpload = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>;
const FiLock = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>;
const FiCheckCircle = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>;
const FiAlertCircle = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>;

export default function BackupSettingsPage() {
  const [backupPassword, setBackupPassword] = useState('');
  const [restorePassword, setRestorePassword] = useState('');
  
  const [isBackingUp, setIsBackingUp] = useState(false);
  const [isRestoring, setIsRestoring] = useState(false);
  
  const [status, setStatus] = useState<{ type: 'success' | 'error', message: string } | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleBackupCloud = async () => {
    if (!backupPassword || backupPassword.length < 6) {
      setStatus({ type: 'error', message: 'Şifre en az 6 karakter olmalıdır.' });
      return;
    }
    
    setIsBackingUp(true);
    setStatus(null);
    try {
      await exportAndUploadBackup(backupPassword);
      setStatus({ type: 'success', message: 'Sohbet geçmişiniz buluta başarıyla şifrelenip yedeklendi!' });
      setBackupPassword('');
    } catch (e: any) {
      setStatus({ type: 'error', message: `Yedekleme başarısız: ${e.message}` });
    } finally {
      setIsBackingUp(false);
    }
  };

  const handleBackupFile = async () => {
    if (!backupPassword || backupPassword.length < 6) {
      setStatus({ type: 'error', message: 'Şifre en az 6 karakter olmalıdır.' });
      return;
    }
    
    setIsBackingUp(true);
    setStatus(null);
    try {
      await exportToFile(backupPassword);
      setStatus({ type: 'success', message: 'Yedekleme dosyanız başarıyla indirildi!' });
      setBackupPassword('');
    } catch (e: any) {
      setStatus({ type: 'error', message: `Yedekleme başarısız: ${e.message}` });
    } finally {
      setIsBackingUp(false);
    }
  };

  const handleRestoreCloud = async () => {
    if (!restorePassword) {
      setStatus({ type: 'error', message: 'Geri yüklemek için şifrenizi girmelisiniz.' });
      return;
    }
    
    setIsRestoring(true);
    setStatus(null);
    try {
      await downloadAndRestoreBackup(restorePassword);
      setStatus({ type: 'success', message: 'Yedek başarıyla buluttan geri yüklendi! Sayfa yenileniyor...' });
      setTimeout(() => window.location.reload(), 1500);
    } catch (e: any) {
      setStatus({ type: 'error', message: `Geri yükleme başarısız. Şifreniz hatalı olabilir. Detay: ${e.message}` });
    } finally {
      setIsRestoring(false);
    }
  };

  const handleRestoreFile = async () => {
    if (!restorePassword) {
      setStatus({ type: 'error', message: 'Geri yüklemek için şifrenizi girmelisiniz.' });
      return;
    }
    if (!selectedFile) {
      setStatus({ type: 'error', message: 'Lütfen bir yedekleme dosyası (.iz veya .json) seçin.' });
      return;
    }
    
    setIsRestoring(true);
    setStatus(null);
    try {
      await importFromFile(restorePassword, selectedFile);
      setStatus({ type: 'success', message: 'Yedek başarıyla dosyadan geri yüklendi! Sayfa yenileniyor...' });
      setTimeout(() => window.location.reload(), 1500);
    } catch (e: any) {
      setStatus({ type: 'error', message: `Dosya geçersiz veya şifre hatalı. Detay: ${e.message}` });
    } finally {
      setIsRestoring(false);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setSelectedFile(e.target.files[0]);
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h1 className={styles.title}>Uçtan Uca Şifreli Yedekleme</h1>
        <p className={styles.subtitle}>
          Sohbet geçmişiniz ve şifreleme anahtarlarınız belirlediğiniz parola ile cihazınızda AES-256-GCM kullanılarak şifrelenir.
          Sunucularımız verilerinizi sadece şifreli (okunamayan) bir formatta saklar.
        </p>
      </div>

      {status && (
        <div className={`${styles.alert} ${status.type === 'success' ? styles.alertSuccess : styles.alertError}`}>
          {status.type === 'success' ? <FiCheckCircle /> : <FiAlertCircle />}
          <span>{status.message}</span>
        </div>
      )}

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>
          <FiUploadCloud /> Yedek Oluştur
        </h2>
        <p className={styles.subtitle} style={{ marginBottom: '1.5rem' }}>
          Tüm verilerinizi şifreleyerek buluta yükleyebilir veya bilgisayarınıza dosya olarak indirebilirsiniz. 
          <strong> Dikkat: Bu şifreyi unutursanız verilerinizi asla kurtaramazsınız!</strong>
        </p>
        
        <div className={styles.inputGroup}>
          <label className={styles.label}>Yedekleme Şifresi (En az 6 karakter)</label>
          <input 
            type="password" 
            className={styles.input} 
            placeholder="Güçlü bir şifre belirleyin" 
            value={backupPassword}
            onChange={e => setBackupPassword(e.target.value)}
          />
        </div>

        <div className={styles.buttonGroup}>
          <button 
            className={`${styles.button} ${styles.buttonPrimary}`} 
            onClick={handleBackupCloud}
            disabled={isBackingUp}
          >
            <FiUploadCloud /> {isBackingUp ? 'İşleniyor...' : 'Buluta Yedekle'}
          </button>
          <button 
            className={`${styles.button} ${styles.buttonSecondary}`} 
            onClick={handleBackupFile}
            disabled={isBackingUp}
          >
            <FiDownload /> {isBackingUp ? 'İşleniyor...' : 'Cihaza İndir'}
          </button>
        </div>
      </div>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>
          <FiDownloadCloud /> Yedekten Geri YüKle
        </h2>
        <p className={styles.subtitle} style={{ marginBottom: '1.5rem' }}>
          Yeni bir cihazda oturum açtığınızda veya verileriniz silindiğinde önceki yedeğinizi geri yükleyebilirsiniz.
        </p>

        <div className={styles.inputGroup}>
          <label className={styles.label}>Yedeği Açmak İçin Şifreniz</label>
          <input 
            type="password" 
            className={styles.input} 
            placeholder="Yedek oluştururken kullandığınız şifre" 
            value={restorePassword}
            onChange={e => setRestorePassword(e.target.value)}
          />
        </div>

        <div 
          className={`${styles.fileDropzone} ${selectedFile ? styles.hasFile : ''}`}
          onClick={() => fileInputRef.current?.click()}
        >
          <FiLock />
          {selectedFile ? (
            <div>
              <div className={styles.fileName}>{selectedFile.name}</div>
              <div className={styles.fileHint}>{(selectedFile.size / 1024).toFixed(2)} KB - Değiştirmek için tıklayın</div>
            </div>
          ) : (
            <div>
              <div className={styles.fileName}>Dosyadan Geri Yükle (İsteğe Bağlı)</div>
              <div className={styles.fileHint}>.iz veya .json dosyasını seçmek için tıklayın</div>
            </div>
          )}
          <input 
            type="file" 
            accept=".iz,.json" 
            className={styles.hiddenInput} 
            ref={fileInputRef}
            onChange={handleFileChange}
          />
        </div>

        <div className={styles.buttonGroup}>
          {selectedFile ? (
            <button 
              className={`${styles.button} ${styles.buttonPrimary}`} 
              onClick={handleRestoreFile}
              disabled={isRestoring}
            >
              <FiUpload /> {isRestoring ? 'Yükleniyor...' : 'Dosyadan Geri Yükle'}
            </button>
          ) : (
            <button 
              className={`${styles.button} ${styles.buttonPrimary}`} 
              onClick={handleRestoreCloud}
              disabled={isRestoring}
            >
              <FiDownloadCloud /> {isRestoring ? 'Yükleniyor...' : 'Buluttan Geri Yükle'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
