enum PermissionAction { view, create, edit, delete, approve, export }

enum AppModule {
  dashboard,

  employees,

  attendance,

  leave,

  payroll,

  reports,

  onboarding,

  notifications,

  settings,

  audit,

  googleSheets,
}

class PermissionKeys {
  static String key(AppModule module, PermissionAction action) =>
      '${module.name}_${action.name}';
}

/// Role matrix — only [enabledRoles] are active in the app right now.

class RolePermissions {
  static const superAdmin = 'super_admin';

  static const employee = 'employee';

  /// Inactive for now; set [includeInactiveRoles] to true to re-enable.

  static const admin = 'admin';

  static const hrManager = 'hr_manager';

  static const manager = 'manager';

  /// Flip to `true` when admin / hr_manager / manager should work again.

  static const bool includeInactiveRoles = false;

  /// `manager` is the department Director role (department-scoped).
  static const Set<String> enabledRoles = {superAdmin, employee, manager};

  static const Set<String> inactiveRoles = {admin, hrManager};

  static bool isRoleEnabled(String role) =>
      includeInactiveRoles || enabledRoles.contains(role);

  static String effectiveRole(String role) =>
      isRoleEnabled(role) ? role : employee;

  /// Human-friendly role label for display (super_admin shown simply as Admin).
  static String roleLabel(String role) {
    switch (effectiveRole(role)) {
      case superAdmin:
      case admin:
        return 'Admin';
      case manager:
        return 'Director';
      case hrManager:
        return 'HR Manager';
      case employee:
        return 'Employee';
      default:
        return role.replaceAll('_', ' ');
    }
  }

  static bool isSuperAdmin(String? role) => role == superAdmin;

  static bool isOrganizationAdmin(String? role) =>
      isSuperAdmin(role) ||
      (includeInactiveRoles && (role == admin || role == hrManager));

  static Map<String, List<String>> get defaults => {
    superAdmin: ['*'],

    employee: [
      'dashboard_view',

      'attendance_view',

      'leave_view',

      'leave_create',

      'notifications_view',
    ],

    // Department Director — scoped to their own department (enforced in code
    // + Firestore rules). Can run their department: hire, attendance, leave.
    manager: [
      'dashboard_view',

      'employees_view',

      'employees_create',

      'employees_edit',

      'attendance_view',

      'attendance_edit',

      'leave_view',

      'leave_approve',

      'reports_view',

      'reports_export',

      'notifications_view',
    ],
  };

  /// Preserved for when [includeInactiveRoles] is turned on.

  static Map<String, List<String>> get inactiveRoleDefaults => {
    admin: [
      'dashboard_view',

      'employees_view',

      'employees_create',

      'employees_edit',

      'employees_delete',

      'attendance_view',

      'attendance_edit',

      'leave_view',

      'leave_approve',

      'payroll_view',

      'payroll_edit',

      'reports_view',

      'reports_export',

      'onboarding_view',

      'onboarding_create',

      'notifications_view',

      'settings_view',

      'settings_edit',

      'audit_view',

      'departments_manage',

      'googleSheets_view',

      'googleSheets_create',

      'googleSheets_edit',

      'googleSheets_delete',
    ],

    hrManager: [
      'dashboard_view',

      'employees_view',

      'employees_create',

      'employees_edit',

      'attendance_view',

      'leave_view',

      'leave_approve',

      'payroll_view',

      'payroll_edit',

      'reports_view',

      'reports_export',

      'onboarding_view',

      'onboarding_create',

      'notifications_view',

      'googleSheets_view',
    ],
  };

  static Map<String, List<String>> get allRoleDefaults =>
      includeInactiveRoles ? {...defaults, ...inactiveRoleDefaults} : defaults;

  static List<String> permissionsForRole(String role) {
    final effective = effectiveRole(role);

    return List<String>.from(
      allRoleDefaults[effective] ?? allRoleDefaults[employee]!,
    );
  }

  static List<String> resolvedPermissions({
    required String role,

    required List<String> storedPermissions,
  }) {
    if (!isRoleEnabled(role)) {
      return permissionsForRole(employee);
    }

    if (storedPermissions.contains('*')) {
      return List<String>.from(storedPermissions);
    }

    if (storedPermissions.isNotEmpty) {
      return List<String>.from(storedPermissions);
    }

    return permissionsForRole(role);
  }

  static bool userHasPermission({
    required String role,

    required List<String> storedPermissions,

    required String permission,
  }) {
    final resolved = resolvedPermissions(
      role: role,

      storedPermissions: storedPermissions,
    );

    if (resolved.contains('*')) return true;

    return resolved.contains(permission);
  }

  static String? validateAssignableRole(String role) {
    if (isRoleEnabled(role)) return role;

    return null;
  }
}

/// One grantable permission (a key + a short action label for the UI).
class GrantPerm {
  const GrantPerm(this.key, this.label);
  final String key;
  final String label;
}

/// A module whose individual permissions an admin can grant per-user.
class GrantModule {
  const GrantModule(this.label, this.icon, this.perms);
  final String label;
  final String icon; // material icon name resolved in the UI
  final List<GrantPerm> perms;
}

/// The catalogue of features an admin can hand to any user from Users & Roles.
/// Deliberately excludes the super-admin-only areas (Users & Roles, Settings,
/// Activity log) so a grant can never escalate someone into an admin.
class GrantableAccess {
  static const List<GrantModule> modules = [
    GrantModule('Dashboard', 'dashboard', [
      GrantPerm('dashboard_view', 'View'),
    ]),
    GrantModule('Employees', 'people', [
      GrantPerm('employees_view', 'View'),
      GrantPerm('employees_create', 'Create'),
      GrantPerm('employees_edit', 'Edit'),
      GrantPerm('employees_delete', 'Delete'),
    ]),
    GrantModule('Attendance', 'clock', [
      GrantPerm('attendance_view', 'View'),
      GrantPerm('attendance_edit', 'Manage'),
    ]),
    GrantModule('Leave', 'leave', [
      GrantPerm('leave_view', 'View'),
      GrantPerm('leave_create', 'Apply'),
      GrantPerm('leave_approve', 'Approve'),
    ]),
    GrantModule('Payroll', 'pay', [
      GrantPerm('payroll_view', 'View'),
      GrantPerm('payroll_edit', 'Edit'),
    ]),
    GrantModule('Reports', 'reports', [
      GrantPerm('reports_view', 'View'),
      GrantPerm('reports_export', 'Export'),
    ]),
    GrantModule('Tables', 'tables', [
      GrantPerm('tables_manage', 'Full access'),
    ]),
    GrantModule('Assets', 'assets', [
      GrantPerm('assets_manage', 'Full access'),
    ]),
    GrantModule('Onboarding', 'onboarding', [
      GrantPerm('onboarding_view', 'View'),
      GrantPerm('onboarding_create', 'Create'),
    ]),
    GrantModule('Sheets & Drive', 'sheets', [
      GrantPerm('googleSheets_view', 'View'),
      GrantPerm('googleSheets_create', 'Create'),
      GrantPerm('googleSheets_edit', 'Edit'),
      GrantPerm('googleSheets_delete', 'Delete'),
    ]),
    GrantModule('Departments', 'departments', [
      GrantPerm('departments_manage', 'Manage'),
    ]),
    GrantModule('Notifications', 'bell', [
      GrantPerm('notifications_view', 'View'),
    ]),
  ];

  /// Every distinct grantable permission key (flattened, de-duplicated).
  static List<String> get allKeys =>
      {for (final m in modules) for (final p in m.perms) p.key}.toList();
}
