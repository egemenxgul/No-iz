import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/auth/providers/account_provider.dart';

class PremiumDashboardScreen extends ConsumerWidget {
  const PremiumDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(accountProvider).activeAccountId;
    final account = ref.watch(accountProvider).accounts.firstWhere(
          (acc) => acc.id == activeId,
          orElse: () => AccountInfo(id: '', username: 'Guest'),
        );

    final currentTier = account.subscriptionTier ?? 'free';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'No-iz Premium',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
            foreground: Paint()
              ..shader = AppColors.liquidGlassFaceGradient.createShader(
                const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
              ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient liquid blobs
          Positioned(
            top: 50,
            right: -80,
            child: _blob(AppColors.prismGold.withValues(alpha: 0.2), 300),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: _blob(AppColors.prismCyan.withValues(alpha: 0.2), 300),
          ),
          
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildCurrentTierCard(currentTier),
              const SizedBox(height: 30),
              Text(
                'Ayrıcalıklar',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildTierOption(
                title: 'No-iz Plus',
                price: '49₺ / Ay',
                features: ['10 GB Cloud Kasa', '2 GB Dosya Gönderimi', '10 Kişilik Grup Sesli/Görüntülü Arama'],
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                isCurrent: currentTier == 'plus',
              ),
              const SizedBox(height: 16),
              _buildTierOption(
                title: 'No-iz Pro',
                price: '99₺ / Ay',
                features: ['50 GB Cloud Kasa', '4 GB Dosya Gönderimi', '20 Kişilik Grup', 'Doğrulanmış Rozeti'],
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                isCurrent: currentTier == 'pro',
              ),
              const SizedBox(height: 16),
              _buildTierOption(
                title: 'No-iz Elite',
                price: '299₺ / Ay',
                features: ['200 GB Cloud Kasa', '10 GB Sınırsız Gönderim', 'Elite Elmas Rozeti', 'VIP Müşteri Hizmetleri'],
                gradient: const LinearGradient(colors: [Color(0xFFFFD97D), Color(0xFFFF9E5E)]),
                isCurrent: currentTier == 'elite',
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTierCard(String tier) {
    String title = 'Free';
    Color glowColor = AppColors.textSecondary;
    if (tier == 'plus') { title = 'Plus'; glowColor = const Color(0xFF3B82F6); }
    if (tier == 'pro') { title = 'Pro'; glowColor = const Color(0xFFEC4899); }
    if (tier == 'elite') { title = 'Elite'; glowColor = const Color(0xFFFFD97D); }

    return LiquidGlassCard(
      blurSigma: 30,
      tintColor: glowColor,
      tintOpacity: 0.1,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.diamond_outlined, color: glowColor, size: 48),
          const SizedBox(height: 16),
          Text(
            'Mevcut Planınız',
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'No-iz $title',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierOption({
    required String title,
    required String price,
    required List<String> features,
    required LinearGradient gradient,
    required bool isCurrent,
  }) {
    return LiquidGlassCard(
      blurSigma: 20,
      border: Border.all(color: isCurrent ? AppColors.specularTop : AppColors.glassBorder, width: isCurrent ? 1.5 : 1.0),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 150, 20)),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Aktif', style: GoogleFonts.inter(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(price, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.glassBorderStrong, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14))),
              ],
            ),
          )),
          const SizedBox(height: 16),
          if (!isCurrent)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.glassLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Yükselt (Yakında)', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
            )
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
