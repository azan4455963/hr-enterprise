/// Maps routes to required permission keys.
class RoutePermissions {
  static const Map<String, String> routeToPermission = {
    '/dashboard': 'dashboard_view',
    '/employees': 'employees_view',
    '/employee-overview': 'employees_view',
    '/employee-search': 'employees_view',
    '/employee-record': 'employees_view',
    '/departments': 'departments_manage',
    '/users': 'users_manage',
    '/activity': 'audit_view',
    '/tables': 'tables_manage',
    '/assets': 'assets_manage',
    '/my-department': 'employees_view',
    '/attendance': 'attendance_view',
    '/leave': 'leave_view',
    '/payroll': 'payroll_view',
    '/reports': 'reports_view',
    '/reminders': 'employees_view',
    '/onboarding': 'onboarding_view',
    '/notifications': 'notifications_view',
    '/settings': 'settings_view',
    '/google-sheets': 'googleSheets_view',
    '/google-drive': 'googleSheets_view',
  };

  static String? permissionForPath(String path) {
    for (final entry in routeToPermission.entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  static const employeeCreatePaths = ['/employees/new'];
  static const payrollWritePermission = 'payroll_edit';
  static const leaveCreatePermission = 'leave_create';
  static const leaveApprovePermission = 'leave_approve';
  static const onboardingCreatePermission = 'onboarding_create';
  static const reportsExportPermission = 'reports_export';
}
