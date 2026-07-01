import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../core/constants/permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/ui_kit.dart';
import '../../features/ai/widgets/ai_assistant_panel.dart';
import '../../features/dashboard/widgets/employee_search_dialog.dart';
import '../../providers/ai_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/google_sheets_providers.dart';
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
    _NavItem('/dashboard', 'Dashboard', Icons.dashboard_rounded),
    _NavItem('/me', 'Dashboard', Icons.dashboard_rounded),
    _NavItem('/my-attendance', 'My Attendance', Icons.event_available_rounded),
    _NavItem('/my-salary', 'My Salary', Icons.account_balance_wallet_rounded),
    _NavItem('/my-department', 'My Department', Icons.groups_2_rounded),
    _NavItem('/departments', 'Departments', Icons.apartment_rounded,
        badgeKey: 'departments'),
    _NavItem('/users', 'Users & Roles', Icons.manage_accounts_rounded,
        badgeKey: 'users'),
    _NavItem('/activity', 'Activity Log', Icons.history_rounded),
    _NavItem('/tables', 'Tables', Icons.grid_on_rounded, badgeKey: 'tables'),
    _NavItem('/assets', 'Assets', Icons.devices_rounded),
    _NavItem('/employees', 'Employees', Icons.people_alt_rounded,
        badgeKey: 'employees'),
    _NavItem('/attendance', 'Attendance', Icons.event_available_rounded),
    _NavItem('/leave', 'Leave', Icons.beach_access_rounded, badgeKey: 'leave'),
    _NavItem('/messages', 'Messages', Icons.chat_bubble_outline_rounded,
        badgeKey: 'messages'),
    _NavItem('/payroll', 'Payroll', Icons.account_balance_wallet_rounded),
    _NavItem(
      '/onboarding',
      'Onboarding',
      Icons.person_add_alt_1_rounded,
      badgeKey: 'onboarding',
    ),
    _NavItem('/reminders', 'Reminders', Icons.notifications_active_rounded,
        badgeKey: 'reminders'),
    _NavItem('/reports', 'Reports', Icons.bar_chart_rounded),
    _NavItem('/google-sheets', 'Sheets & Drive', Icons.table_chart_rounded),
  ];

  /// Employee-only nav items (what employees can see)
  static const _employeeOnlyPaths = [
    '/me',
    '/leave',
    '/my-salary',
    '/my-attendance',
    '/messages',
  ];

  /// Navigate, and stamp "seen" for modules whose badge counts new items since
  /// the user last opened them (employees / tables / departments).
  void _navigate(String path) {
    final uid = ref.read(currentUserProvider).valueOrNull?.id;
    if (uid != null) {
      final module = path.startsWith('/employees')
          ? 'employees'
          : path.startsWith('/tables')
              ? 'tables'
              : path.startsWith('/departments')
                  ? 'departments'
                  : null;
      if (module != null) {
        ref.read(userRepositoryProvider).markSeen(uid, module);
      }
    }
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    // Keep the employee auto-sync worker alive while the app shell is mounted.
    ref.watch(employeeSheetSyncProvider);
    final rbac = ref.watch(rbacServiceProvider);
    final access = user != null ? rbac.getModuleAccess(user) : <String, bool>{};
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final location = GoRouterState.of(context).uri.path;
    final employeeViewMode = ref.watch(employeeViewModeProvider);
    final isAdmin = user != null && RolePermissions.isSuperAdmin(user.role);
    final isEmployeeUser = user?.role == RolePermissions.employee;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final visibleItems = _navItems.where((item) {
      // If in employee view mode, only show employee-accessible items
      if (employeeViewMode) {
        return _employeeOnlyPaths.contains(item.path);
      }
      final key = item.path.replaceFirst('/', '');
      return access[key] ?? true;
    }).toList();

    final leaveBadge = ref
        .watch(pendingLeaveProvider)
        .when(data: (l) => l.length, loading: () => 0, error: (_, _) => 0);
    final onboardingBadge = ref.watch(onboardingPendingCountProvider);
    final alertsBadge = ref.watch(unreadNotificationsCountProvider);
    final messagesBadge = ref.watch(unreadMessagesCountProvider);
    final usersBadge = ref.watch(accessRequestsBadgeProvider);
    final remindersBadge = ref.watch(remindersBadgeProvider);
    final employeesBadge = ref.watch(newEmployeesCountProvider);
    final tablesBadge = ref.watch(newTablesCountProvider);
    final departmentsBadge = ref.watch(newDepartmentsCountProvider);

    int badgeFor(String? key) {
      switch (key) {
        case 'leave':
          return leaveBadge;
        case 'onboarding':
          return onboardingBadge;
        case 'messages':
          return messagesBadge;
        case 'users':
          return usersBadge;
        case 'reminders':
          return remindersBadge;
        case 'employees':
          return employeesBadge;
        case 'tables':
          return tablesBadge;
        case 'departments':
          return departmentsBadge;
        default:
          return 0;
      }
    }

    var selectedIndex = visibleItems.indexWhere(
      (n) => location.startsWith(n.path),
    );
    if (selectedIndex < 0) selectedIndex = 0;

    final content = Column(
      children: [
        _TopBar(
          userName: user?.displayName ?? 'User',
          role: RolePermissions.roleLabel(
              user?.role ?? RolePermissions.employee),
          photoUrl: user?.photoUrl,
          alertsBadge: alertsBadge,
          isDark: isDark,
          onSearch: () => showEmployeeSearchDialog(context, ref),
          onNotifications: () => context.go('/notifications'),
          onSettings: () => context.go('/settings'),
          onProfile: () => context.go('/profile'),
          onToggleDarkMode: () =>
              ref.read(themeModeProvider.notifier).toggle(),
          onSignOut: () => _signOut(context, ref),
          showMenu: !isDesktop,
          employeeViewMode: employeeViewMode,
          isAdmin: isAdmin,
          onToggleEmployeeView: isAdmin
              ? () => ref.read(employeeViewModeProvider.notifier).state =
                    !employeeViewMode
              : null,
        ),
        Expanded(child: widget.child),
      ],
    );

    final Widget baseScaffold;
    if (isDesktop) {
      baseScaffold = Scaffold(
        backgroundColor: AppColors.canvas,
        body: Row(
          children: [
            _Sidebar(
              items: visibleItems,
              selectedPath: location,
              user: user,
              badgeFor: badgeFor,
              onSelect: (path) => _navigate(path),
              onAddEmployee: () =>
                  _navigate(isEmployeeUser ? '/my-info' : '/employees/new'),
              onSettings: () => context.go('/settings'),
              onSignOut: () => _signOut(context, ref),
            ),
            Expanded(child: content),
          ],
        ),
      );
    } else {
      baseScaffold = Scaffold(
        backgroundColor: AppColors.canvas,
        drawer: Drawer(
          backgroundColor: AppColors.sidebarBg,
          child: _Sidebar(
            items: visibleItems,
            selectedPath: location,
            user: user,
            badgeFor: badgeFor,
            onSelect: (path) {
              Navigator.pop(context);
              _navigate(path);
            },
            onAddEmployee: () {
              Navigator.pop(context);
              _navigate(isEmployeeUser ? '/my-info' : '/employees/new');
            },
            onSettings: () {
              Navigator.pop(context);
              context.go('/settings');
            },
            onSignOut: () => _signOut(context, ref),
            expanded: true,
          ),
        ),
        body: content,
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.surface,
          selectedIndex: selectedIndex.clamp(0, 4),
          onDestinationSelected: (i) {
            if (i < visibleItems.length) _navigate(visibleItems[i].path);
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
      );
    }

    // AI assistant: floating launcher (bottom-right) + slide-in panel (left).
    // Admin-only.
    final aiOpen = ref.watch(aiPanelOpenProvider);
    return Stack(
      children: [
        baseScaffold,
        if (aiOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () =>
                  ref.read(aiPanelOpenProvider.notifier).state = false,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          left: aiOpen ? 0 : -AiAssistantPanel.width,
          child: const AiAssistantPanel(),
        ),
        // Hide the AI launcher on the Tables screens — it overlaps the
        // editor's footer sheet-tabs and clutters the table view.
        if (isAdmin && !aiOpen && !location.startsWith('/tables'))
          Positioned(
            right: 20,
            bottom: 20,
            child: _AiLauncher(
              onTap: () =>
                  ref.read(aiPanelOpenProvider.notifier).state = true,
            ),
          ),
      ],
    );
  }
}

/// Floating button that opens the AI assistant panel.
class _AiLauncher extends StatelessWidget {
  const _AiLauncher({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandBlue, AppColors.primary],
            ),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, {this.badgeKey});

  final String path;
  final String label;
  final IconData icon;
  final String? badgeKey;
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  ref.read(skipBiometricOnLoginProvider.notifier).state = true;
  try {
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go('/login');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }
}

/// ── Top bar (shared across all screens) ──────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.userName,
    required this.role,
    required this.alertsBadge,
    required this.onSearch,
    required this.onNotifications,
    required this.onSettings,
    required this.showMenu,
    this.photoUrl,
    this.isDark = false,
    this.onProfile,
    this.onToggleDarkMode,
    this.onSignOut,
    this.employeeViewMode = false,
    this.isAdmin = false,
    this.onToggleEmployeeView,
  });

  final String userName;
  final String role;
  final int alertsBadge;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final bool showMenu;
  final String? photoUrl;
  final bool isDark;
  final VoidCallback? onProfile;
  final VoidCallback? onToggleDarkMode;
  final VoidCallback? onSignOut;
  final bool employeeViewMode;
  final bool isAdmin;
  final VoidCallback? onToggleEmployeeView;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          if (showMenu)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.heading),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          else
            const Text(
              'HR Command',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.brandNavy,
              ),
            ),
          const SizedBox(width: 20),
          Expanded(
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 40,
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textFaint,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search employees, documents, or actions...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _IconBtn(
            icon: Icons.notifications_none_rounded,
            onTap: onNotifications,
            showDot: alertsBadge > 0,
          ),
          const SizedBox(width: 6),
          _IconBtn(icon: Icons.settings_outlined, onTap: onSettings),
          // Employee View toggle - only for admin/super_admin
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: employeeViewMode
                    ? 'Switch to Admin View'
                    : 'Switch to Employee View',
                child: InkWell(
                  onTap: onToggleEmployeeView,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: employeeViewMode
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.brandNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: employeeViewMode
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.brandNavy.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          employeeViewMode
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 16,
                          color: employeeViewMode
                              ? AppColors.success
                              : AppColors.brandNavy,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          employeeViewMode ? 'Employee View' : 'Admin View',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: employeeViewMode
                                ? AppColors.success
                                : AppColors.brandNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 14),
          Container(width: 1, height: 28, color: AppColors.cardBorder),
          const SizedBox(width: 14),
          PopupMenuButton<String>(
            tooltip: 'Account',
            position: PopupMenuPosition.under,
            onSelected: (v) {
              if (v == 'profile') {
                onProfile?.call();
              } else if (v == 'settings') {
                onSettings();
              } else if (v == 'dark') {
                onToggleDarkMode?.call();
              } else if (v == 'signout') {
                onSignOut?.call();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(children: [
                  Icon(Icons.person_outline_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('My Profile'),
                ]),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Settings'),
                ]),
              ),
              PopupMenuItem(
                value: 'dark',
                child: Row(children: [
                  Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 18),
                  const SizedBox(width: 10),
                  Text(isDark ? 'Light mode' : 'Dark mode'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(children: [
                  Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Sign out', style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                (photoUrl != null && photoUrl!.isNotEmpty)
                    ? CircleAvatar(
                        radius: 17, backgroundImage: NetworkImage(photoUrl!))
                    : InitialAvatar(name: userName, size: 34),
                const SizedBox(width: 10),
                if (MediaQuery.of(context).size.width > 600)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading,
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                const Icon(Icons.arrow_drop_down_rounded,
                    color: AppColors.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.textBody),
          ),
          if (showDot)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ── Sidebar ──────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedPath,
    required this.user,
    required this.badgeFor,
    required this.onSelect,
    required this.onAddEmployee,
    required this.onSettings,
    required this.onSignOut,
    this.expanded = false,
  });

  final List<_NavItem> items;
  final String selectedPath;
  final dynamic user;
  final int Function(String? badgeKey) badgeFor;
  final void Function(String path) onSelect;
  final VoidCallback onAddEmployee;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final width = expanded ? double.infinity : 244.0;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HR Enterprise',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandNavy,
                      ),
                    ),
                    Text(
                      'MANAGEMENT PORTAL',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Nav
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final item in items)
                  _NavTile(
                    item: item,
                    selected: selectedPath.startsWith(item.path),
                    badge: badgeFor(item.badgeKey),
                    onTap: () => onSelect(item.path),
                  ),
              ],
            ),
          ),
          // Add Employee CTA (employees see "My Information" instead)
          Builder(builder: (context) {
            final isEmployee = user != null &&
                user.role == RolePermissions.employee;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: isEmployee ? 'My Information' : 'Add Employee',
                  icon: isEmployee ? Icons.badge_outlined : Icons.add,
                  onPressed: onAddEmployee,
                ),
              ),
            );
          }),
          const Divider(height: 1, color: AppColors.cardBorder),
          _FooterTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onSettings,
          ),
          _FooterTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            onTap: onSignOut,
            danger: true,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: selected ? Colors.white : AppColors.textBody,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textBody,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white24 : AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterTile extends StatelessWidget {
  const _FooterTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.textBody;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
