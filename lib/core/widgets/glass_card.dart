import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.onTap,
    this.width,
    this.height,
    this.blurSigma = 12,
    this.lightSurfaceAlphaTop = 0.85,
    this.lightSurfaceAlphaBottom = 0.55,
    this.darkSurfaceAlphaTop = 0.08,
    this.darkSurfaceAlphaBottom = 0.03,
    this.borderAlpha = 0.6,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final double blurSigma;
  final double lightSurfaceAlphaTop;
  final double lightSurfaceAlphaBottom;
  final double darkSurfaceAlphaTop;
  final double darkSurfaceAlphaBottom;
  final double borderAlpha;

  /// Strong frosted glass — background stays visible through the card.
  factory GlassCard.frosted({
    Key? key,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
    double borderRadius = 20,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return GlassCard(
      key: key,
      padding: padding,
      borderRadius: borderRadius,
      onTap: onTap,
      width: width,
      height: height,
      blurSigma: 22,
      lightSurfaceAlphaTop: 0.28,
      lightSurfaceAlphaBottom: 0.14,
      darkSurfaceAlphaTop: 0.14,
      darkSurfaceAlphaBottom: 0.06,
      borderAlpha: 0.45,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: darkSurfaceAlphaTop),
                      Colors.white.withValues(alpha: darkSurfaceAlphaBottom),
                    ]
                  : [
                      Colors.white.withValues(alpha: lightSurfaceAlphaTop),
                      Colors.white.withValues(alpha: lightSurfaceAlphaBottom),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: borderAlpha * 0.35)
                  : Colors.white.withValues(alpha: borderAlpha),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }
    return content;
  }
}
