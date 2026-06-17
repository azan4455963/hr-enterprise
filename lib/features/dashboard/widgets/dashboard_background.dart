import 'package:flutter/material.dart';

import '../../../core/widgets/premium_backdrop.dart';

/// Dashboard full-screen backdrop — matches login and app shell.
class DashboardBackground extends StatelessWidget {
  const DashboardBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumBackdrop(child: child);
  }
}
