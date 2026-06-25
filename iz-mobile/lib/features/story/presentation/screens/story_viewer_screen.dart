import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import '../../models/story_model.dart';
import '../../providers/story_provider.dart';
import '../../../messages/providers/media_upload_service.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final FriendStoryFeedModel feedItem;

  const StoryViewerScreen({
    super.key,
    required this.feedItem,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  double _progress = 0.0;
  Timer? _timer;
  bool _isLoading = true;
  String? _error;
  Uint8List? _decryptedBytes;
  String? _decryptedCaption;
  bool _isPaused = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadStoryMedia();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStoryMedia() async {
    _timer?.cancel();
    _fadeCtrl.reset();
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _decryptedBytes = null;
        _decryptedCaption = null;
        _progress = 0.0;
      });
    }

    final story = widget.feedItem.stories[_currentIndex];

    try {
      final mediaKey =
          await ref.read(storyProvider.notifier).getCachedStoryKey(story.id);

      if (mediaKey == null) {
        throw 'Bu duruma ait şifreleme anahtarı yerel cihazda bulunamadı.';
      }

      if (story.caption != null && story.caption!.isNotEmpty) {
        _decryptedCaption = await ref.read(storyProvider.notifier).decryptCaption(
              story.caption,
              mediaKey,
            );
      }

      if (story.mediaType == 'image' || story.mediaType == 'video') {
        final uploadSvc = ref.read(mediaUploadServiceProvider);
        _decryptedBytes = await uploadSvc.downloadAndDecryptMedia(
          mediaUrl: story.mediaUrl,
          mediaKeyBase64: mediaKey,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _fadeCtrl.forward();
        _startTimer();
        
        // Mark as viewed on backend (fire and forget)
        ref.read(storyProvider.notifier).markStoryAsViewed(story.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
        _fadeCtrl.forward();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    const duration = Duration(milliseconds: 50);
    const totalSteps = 100;
    var step = 0;

    _timer = Timer.periodic(duration, (timer) {
      if (_isPaused) return;
      step++;
      if (mounted) {
        setState(() {
          _progress = step / totalSteps;
        });
      }
      if (step >= totalSteps) {
        timer.cancel();
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.feedItem.stories.length - 1) {
      setState(() => _currentIndex++);
      _loadStoryMedia();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadStoryMedia();
    } else {
      _loadStoryMedia();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final story = widget.feedItem.stories[_currentIndex];
    final initial = widget.feedItem.displayName.isNotEmpty
        ? widget.feedItem.displayName[0].toUpperCase()
        : '?';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
              Navigator.pop(context);
            }
          },
          onLongPressStart: (_) {
            HapticFeedback.lightImpact();
            setState(() => _isPaused = true);
          },
          onLongPressEnd: (_) {
            setState(() => _isPaused = false);
          },
          onTapUp: (details) {
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width * 0.3) {
              _prevStory();
            } else {
              _nextStory();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background ──────────────────────────────────────────
              Container(color: Colors.black),

              // ── Content ─────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: _isLoading
                      ? _buildLoader()
                      : _error != null
                          ? _buildErrorState()
                          : _decryptedBytes != null
                              ? Image.memory(
                                  _decryptedBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : _buildTextStory(),
                ),
              ),

              // ── Top vignette ─────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 200,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom vignette ───────────────────────────────────────
              if (!_isLoading && _error == null &&
                  _decryptedBytes != null && _decryptedCaption != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 56),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _decryptedCaption!,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Top overlay: progress + header ───────────────────────
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress segments
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: List.generate(
                          widget.feedItem.stories.length,
                          (index) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: index < _currentIndex
                                      ? 1.0
                                      : index == _currentIndex
                                          ? _progress
                                          : 0.0,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.25),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.accent,
                                  ),
                                  minHeight: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Avatar + Name + E2E badge + Close
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  AppColors.accentSecondary,
                                ],
                              ),
                            ),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1C1C2E),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.feedItem.displayName,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.accent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accent
                                                .withValues(alpha: 0.6),
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Uçtan Uca Şifreli',
                                      style: GoogleFonts.inter(
                                        color: AppColors.accentLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Close button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Şifre çözülüyor...',
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextStory() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.3),
            AppColors.accentSecondary.withValues(alpha: 0.2),
            const Color(0xFF1C1C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Text(
            _decryptedCaption ?? '[Metin Durumu]',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.4,
              letterSpacing: -0.4,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
