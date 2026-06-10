import 'package:flutter/material.dart';

class AppColors {
  // ─── Background Layers ───────────────────────────────────────────────────
  /// Very deep base — near black with a warm indigo tint
  static const Color bgBase = Color(0xFF060812);
  /// Slightly elevated surface with subtle indigo haze
  static const Color bgSurface = Color(0xFF0D1120);
  /// Card / panel layer
  static const Color bgElevated = Color(0xFF141928);
  /// Hover / pressed state
  static const Color bgHover = Color(0xFF1F2740);

  // ─── Glass Surfaces ───────────────────────────────────────────────────────
  /// Translucent white tint for frosted-glass panels (iOS liquid glass)
  static const Color glassLight = Color(0x14FFFFFF);
  static const Color glassMedium = Color(0x1EFFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color glassBorderStrong = Color(0x40FFFFFF);
  static const Color glassDark = Color(0x0AFFFFFF);

  // ─── Accent Colors ────────────────────────────────────────────────────────
  /// Vibrant indigo-violet accent (iOS default blue/indigo feel)
  static const Color accent = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);
  static const Color accentGlow = Color(0xFFA5B4FC);
  static const Color accentDim = Color(0x296366F1);
  static const Color accentBorder = Color(0x4D6366F1);

  /// Secondary purple for gradient complements
  static const Color accentSecondary = Color(0xFF8B5CF6);

  // ─── Semantic Colors ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF34D399);
  static const Color successDim = Color(0x2234D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFF4B6E);
  static const Color dangerDim = Color(0x29FF4B6E);

  // ─── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5FF);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textMuted = Color(0xFF4E5B7A);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ─── Borders & Dividers ───────────────────────────────────────────────────
  static const Color border = Color(0x1A6366F1);
  static const Color divider = Color(0x0DFFFFFF);
}
