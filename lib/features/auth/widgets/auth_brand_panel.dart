import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key, required this.isDark, this.compact = false});

  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: isDark ? Colors.white : AppColors.lightText,
        );
    final subtitleColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: EdgeInsets.all(compact ? 0 : 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient(isDark),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 40,
              color: Colors.white,
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.85, 0.85)),
          SizedBox(height: compact ? 20 : 32),
          Text(
            AppConstants.appName,
            style: titleStyle,
            textAlign: compact ? TextAlign.center : TextAlign.start,
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.15, end: 0),
          const SizedBox(height: 10),
          Text(
            'Enterprise HR Management',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
          ).animate().fadeIn(delay: 120.ms),
          if (!compact) ...[
            const SizedBox(height: 40),
            AuthFeatureRow(
              icon: Icons.schedule_rounded,
              label: 'Attendance & QR check-in',
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            AuthFeatureRow(
              icon: Icons.beach_access_rounded,
              label: 'Leave & payroll in one place',
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            AuthFeatureRow(
              icon: Icons.shield_rounded,
              label: 'Role-based secure access',
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class AuthFeatureRow extends StatelessWidget {
  const AuthFeatureRow({
    super.key,
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
