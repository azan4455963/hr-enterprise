import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/asset_paths.dart';
import '../theme/app_colors.dart';

/// Full-screen login backdrop: HR photo + readable overlay + glass-friendly tint.
class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({
    super.key,
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AssetPaths.loginBackground,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) =>
              Container(decoration: AppColors.loginBackground(isDark)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0B1220).withValues(alpha: 0.48),
                      const Color(0xFF1E1B4B).withValues(alpha: 0.42),
                      const Color(0xFF134E4A).withValues(alpha: 0.38),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.45),
                      const Color(0xFFEEF2FF).withValues(alpha: 0.38),
                      const Color(0xFFE0F7FA).withValues(alpha: 0.35),
                    ],
            ),
          ),
        ),
        _GlowOrb(
          top: -80,
          right: -60,
          size: 280,
          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
        _GlowOrb(
          bottom: -100,
          left: -80,
          size: 320,
          color: AppColors.loginBackgroundAccent
              .withValues(alpha: isDark ? 0.1 : 0.16),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    );
  }
}
