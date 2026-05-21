import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFF22D3EE);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color loginBackgroundAccent = Color(0xFF6BDBF2);

  // Light
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xE6FFFFFF);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0x1A000000);

  // Dark
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0x331E293B);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0x1AFFFFFF);

  static LinearGradient primaryGradient(bool isDark) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
            : [const Color(0xFF6366F1), const Color(0xFF818CF8)],
      );

  /// Login screen — indigo + brand cyan, soft professional gradient.
  /// Premium dashboard — deep space gradient.
  static const LinearGradient premiumBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D0D2B),
      Color(0xFF1A1A5E),
      Color(0xFF0D2D5E),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  static Color premiumGlassBorder = Colors.white.withValues(alpha: 0.12);
  static Color premiumGlassSurface = Colors.white.withValues(alpha: 0.06);
  static Color premiumTextMuted = Colors.white.withValues(alpha: 0.4);
  static Color premiumTextSoft = Colors.white.withValues(alpha: 0.6);

  static BoxDecoration loginBackground(bool isDark) => BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment(-0.8, -1),
                end: Alignment(1.2, 1.2),
                colors: [
                  Color(0xFF0B1220),
                  Color(0xFF1E1B4B),
                  Color(0xFF134E4A),
                ],
                stops: [0.0, 0.55, 1.0],
              )
            : const LinearGradient(
                begin: Alignment(-0.6, -1),
                end: Alignment(1.1, 1),
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFEEF2FF),
                  Color(0xFFE0F7FA),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
      );
}
