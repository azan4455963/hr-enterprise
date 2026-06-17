import 'package:flutter/material.dart';

/// Shared full-screen backdrop for dashboard and other premium screens.
/// (The login/register screens use [LoginBackdrop], which has the photo.)
class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({
    super.key,
    required this.child,
    this.isDark = false,
  });

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
          ),
        ),
        child,
      ],
    );
  }
}
