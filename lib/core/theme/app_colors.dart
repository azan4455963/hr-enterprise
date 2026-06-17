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

  // ── Stitch light design system ─────────────────────────────────
  /// Deep navy used for the brand wordmark, headings and primary buttons.
  static const Color brandNavy = Color(0xFF1E3A8A);
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandBlueSoft = Color(0xFFEFF4FF);

  /// App canvas + sidebar.
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color sidebarBg = Color(0xFFEEF2FF);
  static const Color sidebarActive = Color(0xFF1E3A8A);

  /// Cards / surfaces.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0);

  /// Text.
  static const Color heading = Color(0xFF0F172A);
  static const Color textBody = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF94A3B8);

  /// Status pills.
  static const Color pillGreenBg = Color(0xFFDCFCE7);
  static const Color pillGreenFg = Color(0xFF16A34A);
  static const Color pillRedBg = Color(0xFFFEE2E2);
  static const Color pillRedFg = Color(0xFFDC2626);
  static const Color pillAmberBg = Color(0xFFFEF3C7);
  static const Color pillAmberFg = Color(0xFFD97706);
  static const Color pillBlueBg = Color(0xFFDBEAFE);
  static const Color pillBlueFg = Color(0xFF2563EB);

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

  /// Login + dashboard dark backdrop — indigo → teal, soft professional.
  static const LinearGradient dashboardDarkGradient = LinearGradient(
    begin: Alignment(-0.8, -1),
    end: Alignment(1.2, 1.2),
    colors: [
      Color(0xFF0B1220),
      Color(0xFF1E1B4B),
      Color(0xFF134E4A),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// Alias for premium/glass screens using the dashboard palette.
  static const LinearGradient premiumBackground = dashboardDarkGradient;

  static Color premiumGlassBorder = Colors.white.withValues(alpha: 0.12);
  static Color premiumGlassSurface = Colors.white.withValues(alpha: 0.06);
  static Color premiumTextMuted = Colors.white.withValues(alpha: 0.4);
  static Color premiumTextSoft = Colors.white.withValues(alpha: 0.6);

  static BoxDecoration loginBackground(bool isDark) => BoxDecoration(
        gradient: isDark
            ? dashboardDarkGradient
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
