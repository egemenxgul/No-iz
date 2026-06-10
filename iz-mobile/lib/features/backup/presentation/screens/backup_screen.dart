import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backup_provider.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _showPasswordDialog({required bool isBackup}) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.cyanAccent.withOpacity(0.2)),
              ),
              title: Row(
                children: [
                  Icon(
                    isBackup ? Icons.cloud_upload : Icons.cloud_download,
                    color: Colors.cyanAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isBackup ? 'Yedekle' : 'Geri Yükle',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBackup 
                        ? 'Yedeklerinizi şifrelemek için bir anahtar şifre belirleyin. Bu şifre olmadan verilerinizi geri yükleyemezsiniz.'
                        : 'Yedeğinizi çözmek için belirlediğiniz anahtar şifreyi girin.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Yedekleme Şifresi',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F1A),
                      prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pwd = _passwordController.text.trim();
                    if (pwd.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lütfen şifre alanını doldurun')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    if (isBackup) {
                      _runBackup(pwd);
                    } else {
                      _runRestore(pwd);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(isBackup ? 'Şifrele & Yedekle' : 'Çöz & Yükle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _runBackup(String password) async {
    try {
      await ref.read(backupProvider.notifier).exportAndUploadBackup(password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sıfır-Bilgi bulut yedeklemesi başarıyla tamamlandı!'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yedekleme hatası: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _runRestore(String password) async {
    try {
      await ref.read(backupProvider.notifier).downloadAndRestoreBackup(password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sohbet geçmişiniz ve oturum anahtarlarınız başarıyla geri yüklendi!'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geri yükleme hatası: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backupState = ref.watch(backupProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        title: const Text('Yedekleme ve Geri Yükleme'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF16162A), Color(0xFF0F0F1A)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Glassmorphic Status Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E38).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.security, size: 48, color: Colors.cyanAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'Sıfır-Bilgi (Zero-Knowledge) Bulut Yedeklemesi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verileriniz yerel cihazınızda AES-256-GCM ile şifrelendikten sonra sunucuya yüklenir. Şifreleme anahtarınız hiçbir zaman sunucuya gönderilmez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const Divider(height: 32, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Son Yedekleme:',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          backupState.lastBackupAt != null
                              ? '${backupState.lastBackupAt!.day}.${backupState.lastBackupAt!.month}.${backupState.lastBackupAt!.year} ${backupState.lastBackupAt!.hour}:${backupState.lastBackupAt!.minute}'
                              : 'Kayıt Yok',
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              if (backupState.isLoading)
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.cyanAccent),
                    const SizedBox(height: 16),
                    Text(
                      'İşlem yapılıyor, lütfen bekleyin...',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    // Backup Button
                    ElevatedButton.icon(
                      onPressed: () => _showPasswordDialog(isBackup: true),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Şimdi Şifreli Yedekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Restore Button
                    OutlinedButton.icon(
                      onPressed: () => _showPasswordDialog(isBackup: false),
                      icon: const Icon(Icons.cloud_download, color: Colors.cyanAccent),
                      label: const Text(
                        'Yedekten Geri Yükle',
                        style: TextStyle(color: Colors.cyanAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),

              if (backupState.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            backupState.error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
