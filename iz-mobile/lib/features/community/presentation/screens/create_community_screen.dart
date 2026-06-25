// Copyright (c) 2026 Egemen GÜL (github.com/egemenxgul)
// Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0)
// See LICENSE in the project root for license information.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/features/community/data/community_service.dart';

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onCreateCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(communityServiceProvider);
      final result = await service.createCommunity(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim().toLowerCase(),
        description: _descController.text.trim(),
        isPublic: _isPublic,
      );

      final slug = result['slug'] as String;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Topluluk başarıyla oluşturuldu!')),
        );
        // Navigate to details screen of the new community
        context.pushReplacement('/communities/detail/$slug');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Topluluk oluşturma hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Yeni Topluluk',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient blobs
          Positioned(
            top: -60,
            right: -60,
            child: _AmbientBlob(color: AppColors.accent.withValues(alpha: 0.12), size: 280),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: _AmbientBlob(color: AppColors.accentSecondary.withValues(alpha: 0.08), size: 240),
          ),

          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Topluluk Detayları',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Name Field
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.inter(color: AppColors.textPrimary),
                          validator: (val) {
                            if (val == null || val.trim().length < 2) {
                              return 'Topluluk adı en az 2 karakter olmalıdır';
                            }
                            return null;
                          },
                          onChanged: (text) {
                            // Auto-generate slug from name if empty/unedited
                            final formatted = text
                                .trim()
                                .toLowerCase()
                                .replaceAll(RegExp(r'\s+'), '-')
                                .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                            _slugController.text = formatted;
                          },
                          decoration: InputDecoration(
                            hintText: 'Topluluk Adı',
                            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.bgSurface.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Slug Field
                        TextFormField(
                          controller: _slugController,
                          style: GoogleFonts.inter(color: AppColors.textPrimary),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Slug/Link alanı boş olamaz';
                            }
                            if (!RegExp(r'^[a-z0-9\-]+$').hasMatch(val)) {
                              return 'Sadece küçük harf, rakam ve tire kullanın';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'topluluk-linki',
                            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                            prefixText: 'iz.app/c/',
                            prefixStyle: GoogleFonts.inter(color: AppColors.accentLight, fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: AppColors.bgSurface.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description Field
                        TextFormField(
                          controller: _descController,
                          style: GoogleFonts.inter(color: AppColors.textPrimary),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Topluluk Açıklaması',
                            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.bgSurface.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Public/Private Switch
                        SwitchListTile(
                          title: Text(
                            'Herkese Açık Topluluk',
                            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Açık topluluklar keşfet sekmesinde görünür ve herkes katılabilir.',
                            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          value: _isPublic,
                          activeThumbColor: AppColors.accent,
                          inactiveTrackColor: AppColors.bgHover,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() {
                              _isPublic = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _onCreateCommunity,
              label: Text(
                'Topluluk Kur',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 0.2),
              ),
              icon: const Icon(Icons.check),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: color),
      ),
    );
  }
}
