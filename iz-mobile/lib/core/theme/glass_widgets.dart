import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LiquidGlassCard — iOS 26/27 style frosted glass with prismatic edges
// Features: multi-layer blur, specular rim light, prismatic tint refraction
// ─────────────────────────────────────────────────────────────────────────────
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final bool showSpecular;
  final bool showPrismatic;
  final List<BoxShadow>? shadow;
  final Border? border;
  final Gradient? backgroundGradient;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 26,
    this.blurSigma = 28,
    this.tintColor,
    this.tintOpacity = 0.1,
    this.showSpecular = true,
    this.showPrismatic = false,
    this.shadow,
    this.border,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      child: Stack(
        children: [
          // ── Layer 1: Blur + glass fill ──────────────────────────────────
          ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  gradient: backgroundGradient ?? LinearGradient(
                    colors: [
                      (tintColor ?? Colors.white).withValues(alpha: tintOpacity + 0.06),
                      (tintColor ?? Colors.white).withValues(alpha: tintOpacity * 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: radius,
                  border: border ?? Border.all(
                    color: AppColors.glassBorder,
                    width: 0.6,
                  ),
                  boxShadow: shadow ?? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 32,
                      spreadRadius: -6,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),

          // ── Layer 2: Prismatic refraction color splash ──────────────────
          if (showPrismatic)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0, left: 0, right: 0,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.prismRose,
                                AppColors.prismCyan,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Layer 3: Top specular rim light ─────────────────────────────
          if (showSpecular)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: radius,
                  child: Container(
                    height: 1.2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.specularTop,
                          AppColors.specularTop,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Layer 4: Inner glow fill (subtle) ──────────────────────────
          if (showSpecular)
            Positioned(
              top: 1,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: radius,
                  child: Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.specularFill, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidGlassSheet — bottom-anchored glass panel (nav bars, sheets)
// ─────────────────────────────────────────────────────────────────────────────
class LiquidGlassSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final double topRadius;
  final bool showSpecular;

  const LiquidGlassSheet({
    super.key,
    required this.child,
    this.padding,
    this.blurSigma = 40,
    this.topRadius = 28,
    this.showSpecular = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(topRadius),
      topRight: Radius.circular(topRadius),
    );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22FFFFFF),
                    Color(0x10FFFFFF),
                  ],
                ),
                borderRadius: radius,
                border: Border(
                  top: BorderSide(color: AppColors.glassBorderStrong, width: 0.8),
                  left: BorderSide(color: AppColors.glassBorder, width: 0.4),
                  right: BorderSide(color: AppColors.glassBorder, width: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 40,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),

        // Top specular line
        if (showSpecular)
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: radius,
                child: Container(
                  height: 1.0,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.specularTop,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidGlassButton — pill-shaped pressable glass button with spring feedback
// ─────────────────────────────────────────────────────────────────────────────
class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Gradient? gradient;
  final bool isDestructive;

  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius = 20,
    this.gradient,
    this.isDestructive = false,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(_) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: Opacity(opacity: _opacity.value, child: child),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    gradient: widget.gradient ?? (widget.isDestructive
                        ? const LinearGradient(
                            colors: [Color(0x30FF4B6E), Color(0x20FF4B6E)],
                          )
                        : AppColors.liquidGlassFaceGradient),
                    borderRadius: radius,
                    border: Border.all(
                      color: widget.isDestructive
                          ? AppColors.danger.withValues(alpha: 0.35)
                          : AppColors.glassBorderStrong,
                      width: 0.6,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
            // Specular top edge
            Positioned(
              top: 0, left: 8, right: 8,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: radius,
                  child: Container(
                    height: 0.8,
                    color: AppColors.specularTop,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GlassCard — backward-compatible legacy widget (enhanced)
// ─────────────────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 22,
    this.blurSigma = 22,
    this.tintColor,
    this.tintOpacity = 0.08,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      blurSigma: blurSigma,
      tintColor: tintColor,
      tintOpacity: tintOpacity,
      showSpecular: true,
      border: border,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidPillTab — iOS 26 segment control pill
// ─────────────────────────────────────────────────────────────────────────────
class LiquidPillTab extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int Function(int)? badgeCount;

  const LiquidPillTab({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.badgeCount,
  });

  @override
  State<LiquidPillTab> createState() => _LiquidPillTabState();
}

class _LiquidPillTabState extends State<LiquidPillTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  int _prev = 0;

  @override
  void initState() {
    super.initState();
    _prev = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(LiquidPillTab old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _prev = old.selectedIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.glassDark.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder, width: 0.6),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = (constraints.maxWidth - 8) / widget.tabs.length;
              return Stack(
                children: [
                  // Sliding active pill
                  AnimatedBuilder(
                    animation: _slideAnim,
                    builder: (context, _) {
                      final from = _prev * tabWidth;
                      final to = widget.selectedIndex * tabWidth;
                      final pos = lerpDouble(from, to, _slideAnim.value)!;
                      return Positioned(
                        left: pos,
                        top: 0, bottom: 0,
                        width: tabWidth,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0x35FFFFFF),
                                        Color(0x14FFFFFF),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: AppColors.glassBorderStrong,
                                      width: 0.6,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 10,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Specular on pill
                            Positioned(
                              top: 0, left: 6, right: 6,
                              child: Container(
                                height: 0.8,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, AppColors.specularTop, Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Tab labels
                  Row(
                    children: List.generate(widget.tabs.length, (i) {
                      final isActive = i == widget.selectedIndex;
                      final badge = widget.badgeCount?.call(i) ?? 0;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onChanged(i);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: tabWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isActive
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 14,
                                    letterSpacing: isActive ? -0.2 : 0,
                                  ),
                                  child: Text(widget.tabs[i]),
                                ),
                                if (badge > 0) ...[
                                  const SizedBox(width: 6),
                                  _BadgePill(count: badge),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BadgePill — count badge
// ─────────────────────────────────────────────────────────────────────────────
class _BadgePill extends StatelessWidget {
  final int count;
  const _BadgePill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidIconButton — glass orb icon button with haptics
// ─────────────────────────────────────────────────────────────────────────────
class LiquidIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;
  final double size;
  final bool glow;

  const LiquidIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
    this.size = 42,
    this.glow = false,
  });

  @override
  State<LiquidIconButton> createState() => _LiquidIconButtonState();
}

class _LiquidIconButtonState extends State<LiquidIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => Transform.scale(scale: _scale.value, child: child),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.glow)
              Container(
                width: widget.size + 8,
                height: widget.size + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(widget.size / 2.8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x2AFFFFFF), Color(0x10FFFFFF)],
                    ),
                    borderRadius: BorderRadius.circular(widget.size / 2.8),
                    border: Border.all(color: AppColors.glassBorder, width: 0.6),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(widget.icon, color: AppColors.textSecondary, size: 20),
                      if (widget.badge != null) widget.badge!,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidFAB — floating action button with glow & specular
// ─────────────────────────────────────────────────────────────────────────────
class LiquidFAB extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;

  const LiquidFAB({super.key, required this.onTap, this.icon = Icons.edit_note_rounded});

  @override
  State<LiquidFAB> createState() => _LiquidFABState();
}

class _LiquidFABState extends State<LiquidFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => Transform.scale(scale: _scale.value, child: child),
        child: Stack(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.50),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: AppColors.accentSecondary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 26),
            ),
            // Top specular edge
            Positioned(
              top: 1, left: 6, right: 6,
              child: Container(
                height: 0.8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.transparent, AppColors.specularTop, Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidAmbientBlob — blurred ambient light orb
// ─────────────────────────────────────────────────────────────────────────────
class LiquidAmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double blur;

  const LiquidAmbientBlob({
    super.key,
    required this.color,
    required this.size,
    this.blur = 60,
  });

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
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GlowRing — animated glow ring (backward compat)
// ─────────────────────────────────────────────────────────────────────────────
class GlowRing extends StatelessWidget {
  final Widget child;
  final Color color;
  final double blurRadius;
  final double spreadRadius;

  const GlowRing({
    super.key,
    required this.child,
    this.color = AppColors.accent,
    this.blurRadius = 24,
    this.spreadRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GlassBadge — pill-shaped translucent badge (backward compat)
// ─────────────────────────────────────────────────────────────────────────────
class GlassBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const GlassBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
