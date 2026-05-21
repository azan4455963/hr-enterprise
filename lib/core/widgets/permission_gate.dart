import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final String permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return fallback ?? const SizedBox.shrink();
    if (user.hasPermission(permission)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

class RoleGate extends ConsumerWidget {
  const RoleGate({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return fallback ?? const SizedBox.shrink();
    if (allowedRoles.contains(user.role)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
