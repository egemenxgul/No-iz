import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz_mobile/features/economy/providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonelik Modelleri'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: subState == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildQuotaInfo(subState),
                    if (subState.scheduledDowngrade != null)
                      _buildDowngradeWarning(subState),
                    const SizedBox(height: 24),
                    _buildPlanCard(context, ref, 'free', 'Iz Core (Free)', '0 ₺ / Ay', 'Temel özellikler, 1GB depolama alanı, Maksimum 5 kişi grup arama.', subState.tier == 'free', subState),
                    const SizedBox(height: 16),
                    _buildPlanCard(context, ref, 'plus', 'Iz Plus', '49 ₺ / Ay', 'Gelişmiş özellikler, 10GB depolama alanı, Maksimum 10 kişi grup arama.', subState.tier == 'plus', subState),
                    const SizedBox(height: 16),
                    _buildPlanCard(context, ref, 'pro', 'Iz Pro', '99 ₺ / Ay', 'Sınırsız Özellikler, 50GB depolama alanı, Maksimum 20 kişi grup arama, Onaylı Rozet.', subState.tier == 'pro', subState),
                    const SizedBox(height: 16),
                    _buildPlanCard(context, ref, 'elite', 'Iz Elite', '299 ₺ / Ay', 'VIP Özellikler, 200GB depolama alanı, Sınırsız grup arama, Elite VIP Rozeti, Öncelikli Destek.', subState.tier == 'elite', subState),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildQuotaInfo(dynamic subState) {
    final usedGb = (subState.storageUsed / (1024 * 1024 * 1024)).toStringAsFixed(2);
    final totalGb = (subState.storageTotal / (1024 * 1024 * 1024)).toStringAsFixed(2);
    final percent = subState.storageUsed / subState.storageTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Depolama Alanınız', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text('$usedGb GB / $totalGb GB Kulanılıyor', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent > 1.0 ? 1.0 : percent,
            backgroundColor: Colors.white12,
            color: percent > 0.8 ? Colors.redAccent : Colors.deepPurpleAccent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          if (percent > 0.8)
            const Text('Alanınız dolmak üzere! Yeni dosyalar için paketinizi yükseltin.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDowngradeWarning(dynamic subState) {
    String dateStr = "Yakında";
    if (subState.periodEnd != null) {
      try {
        final parsed = DateTime.parse(subState.periodEnd);
        dateStr = "${parsed.day}.${parsed.month}.${parsed.year}";
      } catch (_) {}
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aboneliğiniz $dateStr tarihinde ${subState.scheduledDowngrade} paketine düşürülecektir.',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, WidgetRef ref, String tierId, String title, String price, String description, bool isCurrent, dynamic subState) {
    final tiers = ['free', 'plus', 'pro', 'elite'];
    final currentIdx = tiers.indexOf(subState.tier);
    final newIdx = tiers.indexOf(tierId);
    final isDowngrade = newIdx < currentIdx;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.deepPurple.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCurrent ? Colors.deepPurpleAccent : Colors.white12, width: isCurrent ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Mevcut Plan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(price, style: const TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          const SizedBox(height: 20),
          if (!isCurrent)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (isDowngrade) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1B4B),
                        title: const Text('Aboneliği Düşür', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'Aboneliğinizi düşürmek üzeresiniz. Bu değişiklik mevcut fatura döneminizin sonunda yürürlüğe girecektir.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Onayla', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }

                  final success = await ref.read(subscriptionProvider.notifier).subscribe(tierId);
                  if (success && context.mounted) {
                    final msg = isDowngrade 
                        ? 'Düşürme talebiniz alındı. Fatura dönemi sonunda uygulanacak.'
                        : '$title paketine başarıyla geçiş yapıldı!';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tierId == 'elite' ? Colors.amber.shade700 : Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                   subState.scheduledDowngrade == tierId ? 'Düşüş Planlandı' : (newIdx < currentIdx ? 'Paketi Düşür' : 'Bu Plana Geç'), 
                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
        ],
      ),
    );
  }
}
