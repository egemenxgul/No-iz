import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import '../../providers/story_provider.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _captionController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  int _selectedGradientIndex = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<List<Color>> _gradients = [
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
    [const Color(0xFF00c6ff), const Color(0xFF0072ff)],
    [const Color(0xFFf12711), const Color(0xFFf5af19)],
    [const Color(0xFF11998e), const Color(0xFF38ef7d)],
    [const Color(0xFFff007f), const Color(0xFF7f00ff)],
    [const Color(0xFF2d3561), const Color(0xFF5D54A4)],
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    _captionController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _textController.clear();
        });
      }
    } catch (e) {
      _showSnack('Dosya seçilemedi: $e', isError: true);
    }
  }

  Future<void> _publishStory() async {
    final hasText = _textController.text.trim().isNotEmpty;
    final hasFile = _selectedFile != null;

    if (!hasText && !hasFile) {
      _showSnack('Lütfen bir metin girin veya medya seçin', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isUploading = true);

    try {
      if (hasFile) {
        final bytes = _selectedFile!.bytes;
        if (bytes == null) throw 'Dosya verisi okunamadı';
        await ref.read(storyProvider.notifier).createStory(
              fileBytes: bytes,
              filename: _selectedFile!.name,
              mimeType: _selectedFile!.extension != null
                  ? 'image/${_selectedFile!.extension}'
                  : 'image/jpeg',
              captionText: _captionController.text.trim().isNotEmpty
                  ? _captionController.text.trim()
                  : null,
            );
      } else {
        final transparent1x1Gif = Uint8List.fromList([
          0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80,
          0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04,
          0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01,
          0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
        ]);
        await ref.read(storyProvider.notifier).createStory(
              fileBytes: transparent1x1Gif,
              filename: 'text_status.gif',
              mimeType: 'text/plain',
              captionText: _textController.text.trim(),
            );
      }

      if (mounted) {
        _showSnack('Durumunuz E2EE şifrelenerek paylaşıldı!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: (isError ? AppColors.danger : AppColors.success)
                    .withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isError ? AppColors.danger : AppColors.success)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      msg,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _selectedFile != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AppBar(
                backgroundColor: AppColors.bgBase.withValues(alpha: 0.75),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20,
                      color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Durum Ekle',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                actions: [
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: _publishStory,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentSecondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.35),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            'Paylaş',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Ambient blobs
            Positioned(
              top: -80,
              right: -60,
              child: _blob(AppColors.accent.withValues(alpha: 0.10), 260),
            ),
            Positioned(
              bottom: 60,
              left: -80,
              child: _blob(AppColors.accentSecondary.withValues(alpha: 0.07), 220),
            ),

            // Content
            FadeTransition(
              opacity: _fadeAnim,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Preview ──────────────────────────────────────
                      if (hasFile)
                        _ImagePreview(
                          file: _selectedFile!,
                          onClear: () => setState(() => _selectedFile = null),
                          captionController: _captionController,
                        )
                      else
                        _TextStoryEditor(
                          controller: _textController,
                          gradients: _gradients,
                          selectedIndex: _selectedGradientIndex,
                          onGradientSelect: (i) =>
                              setState(() => _selectedGradientIndex = i),
                        ),
                      const SizedBox(height: 28),

                      // ── Pick photo button ─────────────────────────────
                      if (!hasFile)
                        _PickPhotoButton(onTap: _pickMedia),
                      const SizedBox(height: 24),

                      // ── E2EE badge ────────────────────────────────────
                      _E2EEBadge(),
                    ],
                  ),
                ),
              ),
            ),

            // Uploading overlay
            if (_isUploading)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 28),
                          decoration: BoxDecoration(
                            color: AppColors.glassMedium,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: AppColors.glassBorder, width: 0.6),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 2.5,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'E2EE Şifreleniyor & Yükleniyor...',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: color),
      ),
    );
  }
}

// ─── Image Preview Card ───────────────────────────────────────────────────────
class _ImagePreview extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onClear;
  final TextEditingController captionController;

  const _ImagePreview({
    required this.file,
    required this.onClear,
    required this.captionController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (file.bytes != null)
                Image.memory(
                  file.bytes!,
                  height: 360,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              // Remove button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onClear,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Caption input
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: TextField(
              controller: captionController,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Açıklama ekleyin (E2EE şifrelenir)...',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.glassMedium,
                prefixIcon: const Icon(Icons.closed_caption_outlined,
                    color: AppColors.textMuted, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      const BorderSide(color: AppColors.glassBorder, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      const BorderSide(color: AppColors.glassBorder, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Text Story Editor ────────────────────────────────────────────────────────
class _TextStoryEditor extends StatelessWidget {
  final TextEditingController controller;
  final List<List<Color>> gradients;
  final int selectedIndex;
  final ValueChanged<int> onGradientSelect;

  const _TextStoryEditor({
    required this.controller,
    required this.gradients,
    required this.selectedIndex,
    required this.onGradientSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Text preview card
        Container(
          height: 320,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradients[selectedIndex],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: gradients[selectedIndex].first.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            maxLines: 6,
            textAlign: TextAlign.center,
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Bugün ne düşünüyorsun?\nYazmaya başla...',
              hintStyle: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Gradient picker
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gradients.length,
            separatorBuilder: (context2, index2) => const SizedBox(width: 10),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onGradientSelect(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradients[i]),
                  border: selectedIndex == i
                      ? Border.all(color: Colors.white, width: 3)
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.2), width: 1),
                  boxShadow: selectedIndex == i
                      ? [
                          BoxShadow(
                            color: gradients[i].first.withValues(alpha: 0.5),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pick Photo Button ────────────────────────────────────────────────────────
class _PickPhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PickPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.glassLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                    ),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Text(
                  'Fotoğraf Seç',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── E2EE Badge ───────────────────────────────────────────────────────────────
class _E2EEBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.glassDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Uçtan Uca Şifreli · 24 Saat Sonra Silinir',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
