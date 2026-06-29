import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/call_provider.dart';
import '../../models/call_session.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/callkit_service.dart';

import 'package:iz_mobile/core/theme/glass_widgets.dart';
class RingingScreen extends ConsumerStatefulWidget {
  final CallSession session;

  const RingingScreen({super.key, required this.session});

  @override
  ConsumerState<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends ConsumerState<RingingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _breathController;
  late Animation<double> _breathAnim;

  String? _callKitId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _breathAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // UX-8: Show native CallKit / ConnectionService incoming call UI
    _showCallKit();
  }

  Future<void> _showCallKit() async {
    final session = widget.session;
    _callKitId = session.callId.isNotEmpty ? session.callId : CallKitService.newCallId();
    await CallKitService().showIncomingCall(
      callId: _callKitId!,
      callerName: session.peerName,
      callerHandle: session.peerId,
      isVideo: session.type == CallType.video,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _breathController.dispose();
    // End the CallKit UI when screen is dismissed
    if (_callKitId != null) {
      CallKitService().endCall(_callKitId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.session.peerName;
    final isVideo = widget.session.type == CallType.video;
    final initial = callerName.isNotEmpty ? callerName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Rich dark gradient base ───────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0B0E1A),
                    Color(0xFF060812),
                  ],
                ),
              ),
            ),
          ),

          // ── Radial glow behind avatar ─────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _breathController,
                builder: (_, __) => Transform.scale(
                  scale: _breathAnim.value,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF3B82F6).withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Ambient top glow ──────────────────────────────────────────
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA855F7).withValues(alpha: 0.14),
                ),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
          ),

          // ── Global frosted glass overlay ──────────────────────────────
          Positioned.fill(
            child: AppBackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(color: Colors.transparent),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Label pill
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AppBackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isVideo ? context.tr(ref, 'incoming_video_call') : context.tr(ref, 'incoming_voice_call'),
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
                              color: const Color(0xFF60A5FA),
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Caller name
                Text(
                  callerName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(ref, 'calling_via_iz'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(),

                // ── Pulsing avatar ────────────────────────────────────
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer ripple 1
                        _buildRipple(
                          _pulseController.value,
                          const Color(0xFF3B82F6),
                          170,
                          0.18,
                        ),
                        // Outer ripple 2
                        _buildRipple(
                          (_pulseController.value + 0.5) % 1.0,
                          const Color(0xFFA855F7),
                          160,
                          0.14,
                        ),
                        // Inner ring
                        Container(
                          width: 138,
                          height: 138,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        // Avatar core
                        AnimatedBuilder(
                          animation: _breathAnim,
                          builder: (_, __) => Transform.scale(
                            scale: _breathAnim.value,
                            child: Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF60A5FA), Color(0xFF4F46E5)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const Spacer(),

                // ── Action buttons ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallButton(
                        icon: Icons.call_end_rounded,
                        label: context.tr(ref, 'reject'),
                        color: const Color(0xFFFF4B6E),
                        onTap: () => ref.read(callProvider.notifier).rejectCall(),
                      ),
                      _CallButton(
                        icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        label: context.tr(ref, 'answer'),
                        color: const Color(0xFF34D399),
                        onTap: () => ref.read(callProvider.notifier).acceptCall(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRipple(double t, Color color, double baseSize, double maxOpacity) {
    final scale = 1.0 + t * 0.9;
    final opacity = maxOpacity * (1.0 - t);
    return Container(
      width: baseSize * scale,
      height: baseSize * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}

// ─── Call Button ──────────────────────────────────────────────────────────────

class _CallButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<_CallButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleCtrl;
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.reverse(),
      onTapUp: (_) {
        _scaleCtrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.forward(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
