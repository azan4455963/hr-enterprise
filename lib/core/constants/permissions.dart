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

  static const Set<String> enabledRoles = {superAdmin, employee};

  static const Set<String> inactiveRoles = {admin, hrManager, manager};

  static bool isRoleEnabled(String role) =>
      includeInactiveRoles || enabledRoles.contains(role);

  static String effectiveRole(String role) =>
      isRoleEnabled(role) ? role : employee;

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

    manager: [
      'dashboard_view',

      'employees_view',

      'attendance_view',

      'attendance_edit',

      'leave_view',

      'leave_approve',

      'reports_view',

      'reports_export',
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
