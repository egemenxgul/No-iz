import 'package:flutter/material.dart';

class AppColors {
  // ─── Deep Chromatic Backgrounds ──────────────────────────────────────────────
  /// Absolute void — deepest layer, slight blue-black tint
  static const Color bgBase = Color(0xFF06070F);
  /// Primary surface — subtle indigo depth
  static const Color bgSurface = Color(0xFF0B0D1A);
  /// Elevated card layer
  static const Color bgElevated = Color(0xFF11142A);
  /// Hover / pressed micro-feedback
  static const Color bgHover = Color(0xFF1A1F3A);

  // ─── Liquid Glass Surfaces ────────────────────────────────────────────────────
  /// Ultra-thin frosted glass — innermost tint (iOS 26 chrome)
  static const Color glassUltraThin = Color(0x08FFFFFF);
  /// Thin glass tint
  static const Color glassThin = Color(0x10FFFFFF);
  /// Standard glass panel
  static const Color glassLight = Color(0x16FFFFFF);
  /// Medium glass (slightly more opaque)
  static const Color glassMedium = Color(0x20FFFFFF);
  /// Border on glass surfaces
  static const Color glassBorder = Color(0x28FFFFFF);
  /// Strong border for depth separation
  static const Color glassBorderStrong = Color(0x45FFFFFF);
  /// Dark tinted glass (inverted panels)
  static const Color glassDark = Color(0x0AFFFFFF);

  // ─── Specular Highlights (iOS 26 Liquid Glass prismatic edges) ───────────────
  /// Top specular edge — white prismatic rim light
  static const Color specularTop = Color(0x60FFFFFF);
  /// Bottom specular edge — cooler, dimmer
  static const Color specularBottom = Color(0x15FFFFFF);
  /// Inner specular fill — barely-there glow inside glass
  static const Color specularFill = Color(0x08FFFFFF);
  /// Prismatic blush — warm rose tint for refractive color
  static const Color prismRose = Color(0x12FF6FA8);
  /// Prismatic cyan — cool complementary refraction
  static const Color prismCyan = Color(0x0E4DD9FF);
  /// Prismatic gold — warm specular warmth
  static const Color prismGold = Color(0x0AFFD97D);

  // ─── Accent Colors ────────────────────────────────────────────────────────────
  /// Primary indigo-violet (iOS blue feel)
  static const Color accent = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);
  static const Color accentGlow = Color(0xFFA5B4FC);
  static const Color accentDim = Color(0x296366F1);
  static const Color accentBorder = Color(0x4D6366F1);

  /// Secondary purple gradient complement
  static const Color accentSecondary = Color(0xFF8B5CF6);

  // ─── Semantic Colors ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF34D399);
  static const Color successDim = Color(0x2234D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFF4B6E);
  static const Color dangerDim = Color(0x29FF4B6E);

  // ─── Text ─────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textMuted = Color(0xFF4E5B7A);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ─── Borders & Dividers ───────────────────────────────────────────────────────
  static const Color border = Color(0x1A6366F1);
  static const Color divider = Color(0x0DFFFFFF);

  // ─── Gradient Presets ────────────────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF08091A), Color(0xFF06070F), Color(0xFF080C1E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.4, 1.0],
  );

  /// Warm prismatic glass gradient — inner face of the glass
  static LinearGradient liquidGlassFaceGradient = const LinearGradient(
    colors: [
      Color(0x20FFFFFF),
      Color(0x08FFFFFF),
      Color(0x12FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
  );
}
