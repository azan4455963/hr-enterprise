import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../core/constants/permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/theme_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _navItems = [
    _NavItem('/dashboard', 'Dashboard', Icons.dashboard_rounded, section: 'Main'),
    _NavItem('/employees', 'Employees', Icons.people_rounded, section: 'Main'),
    _NavItem('/attendance', 'Attendance', Icons.access_time_rounded, section: 'HR'),
    _NavItem('/leave', 'Leave', Icons.beach_access_rounded, section: 'HR', badgeKey: 'leave'),
    _NavItem('/payroll', 'Payroll', Icons.payments_rounded, section: 'HR'),
    _NavItem('/reports', 'Reports', Icons.assessment_rounded, section: 'System'),
    _NavItem('/onboarding', 'Onboarding', Icons.person_add_rounded, section: 'System', badgeKey: 'onboarding'),
    _NavItem('/notifications', 'Alerts', Icons.notifications_rounded, section: 'System', badgeKey: 'alerts'),
    _NavItem('/settings', 'Settings', Icons.settings_rounded, section: 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final rbac = ref.watch(rbacServiceProvider);
    final access = user != null ? rbac.getModuleAccess(user) : <String, bool>{};
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final location = GoRouterState.of(context).uri.path;

    var selectedIndex = _navItems.indexWhere((n) => location.startsWith(n.path));
    if (selectedIndex < 0) selectedIndex = 0;

    final visibleItems = _navItems.where((item) {
      final key = item.path.replaceFirst('/', '');
      return access[key] ?? true;
    }).toList();

    final selectedPath = location;
    final leaveBadge = ref.watch(pendingLeaveProvider).when(
          data: (l) => l.length,
          loading: () => 0,
          error: (_, __) => 0,
        );
    final onboardingBadge = ref.watch(onboardingPendingCountProvider);
    final alertsBadge = ref.watch(unreadNotificationsCountProvider);

    int badgeFor(String? key) {
      switch (key) {
        case 'leave':
          return leaveBadge;
        case 'onboarding':
          return onboardingBadge;
        case 'alerts':
          return alertsBadge;
        default:
          return 0;
      }
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D2B),
        body: Row(
          children: [
            _PremiumSidebar(
              items: visibleItems,
              selectedPath: selectedPath,
              user: user,
              badgeFor: badgeFor,
              onSelect: (path) => context.go(path),
              onSignOut: () => _signOut(context, ref),
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, 4),
        onDestinationSelected: (i) {
          if (i < visibleItems.length) context.go(visibleItems[i].path);
        },
        destinations: visibleItems.take(5).map((n) {
          final badge = badgeFor(n.badgeKey);
          return NavigationDestination(
            icon: badge > 0
                ? Badge(label: Text('$badge'), child: Icon(n.icon))
                : Icon(n.icon),
            label: n.label,
          );
        }).toList(),
      ),
      drawer: Drawer(
        child: _PremiumSidebar(
          items: visibleItems,
          selectedPath: selectedPath,
          user: user,
          badgeFor: badgeFor,
          onSelect: (path) {
            Navigator.pop(context);
            context.go(path);
          },
          onSignOut: () => _signOut(context, ref),
          expanded: true,
        ),
      ),
      appBar: AppBar(
        title: Text(
          visibleItems
              .firstWhere(
                (n) => selectedPath.startsWith(n.path),
                orElse: () => visibleItems.first,
              )
              .label,
        ),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(
    this.path,
    this.label,
    this.icon, {
    required this.section,
    this.badgeKey,
  });

  final String path;
  final String label;
  final IconData icon;
  final String section;
  final String? badgeKey;
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  ref.read(skipBiometricOnLoginProvider.notifier).state = true;
  try {
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go('/login');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppException.from(e).message)),
      );
    }
  }
}

class _PremiumSidebar extends StatelessWidget {
  const _PremiumSidebar({
    required this.items,
    required this.selectedPath,
    required this.user,
    required this.badgeFor,
    required this.onSelect,
    required this.onSignOut,
    this.expanded = false,
  });

  final List<_NavItem> items;
  final String selectedPath;
  final dynamic user;
  final int Function(String? badgeKey) badgeFor;
  final void Function(String path) onSelect;
  final VoidCallback onSignOut;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final width = expanded ? double.infinity : 210.0;
    final name = user?.displayName as String? ?? 'User';
    final role = RolePermissions.effectiveRole(
      user?.role ?? RolePermissions.employee,
    ).replaceAll('_', ' ');
    final initial =
        name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.groups_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HR Enterprise',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'v2.0 Premium',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              children: _buildSections(),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSignOut,
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  tooltip: 'Sign out',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections() {
    final sections = ['Main', 'HR', 'System'];
    final widgets = <Widget>[];
    for (final section in sections) {
      final sectionItems = items.where((i) => i.section == section).toList();
      if (sectionItems.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(
            section,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 0.08 * 16,
            ),
          ),
        ),
      );
      for (final item in sectionItems) {
        final selected = selectedPath.startsWith(item.path);
        final badge = badgeFor(item.badgeKey);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(item.path),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: selected
                        ? const Border(
                            left: BorderSide(color: AppColors.primary, width: 3),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 15,
                        color: selected
                            ? const Color(0xFFA5B4FC)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w500 : FontWeight.normal,
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      if (badge > 0)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$badge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}
