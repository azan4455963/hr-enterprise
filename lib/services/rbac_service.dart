import '../core/constants/permissions.dart';
import '../models/user_model.dart';

class RbacService {
  List<String> getPermissionsForRole(String role) {
    return RolePermissions.permissionsForRole(role);
  }

  bool can(UserModel? user, String permission) {
    if (user == null) return false;
    return user.hasPermission(permission);
  }

  bool canAccessModule(
    UserModel? user,
    AppModule module,
    PermissionAction action,
  ) {
    if (user == null) return false;
    return user.hasPermission(PermissionKeys.key(module, action));
  }

  bool canViewSalary(UserModel? user) {
    if (user == null) return false;
    return user.canViewSalary();
  }

  bool canAccessDepartment(UserModel? user, String? targetDepartmentId) {
    if (user == null) return false;
    if (RolePermissions.isSuperAdmin(user.role)) return true;
    if (RolePermissions.includeInactiveRoles &&
        (user.role == RolePermissions.admin ||
            user.role == RolePermissions.hrManager)) {
      return true;
    }
    if (RolePermissions.includeInactiveRoles &&
        user.role == RolePermissions.manager) {
      return user.departmentId == targetDepartmentId;
    }
    return false;
  }

  Map<String, bool> getModuleAccess(UserModel user) => {
    // Plain employees use "My Space"; the admin dashboard is hidden from them.
    'dashboard':
        can(user, 'dashboard_view') && user.role != RolePermissions.employee,
    'me': user.role == RolePermissions.employee,
    'employees': can(user, 'employees_view'),
    'employee-search': can(user, 'employees_view'),
    'employee-record': can(user, 'employees_view'),
    'departments': can(user, 'departments_manage'),
    'users': RolePermissions.isSuperAdmin(user.role),
    'activity': RolePermissions.isSuperAdmin(user.role),
    'tables': RolePermissions.isSuperAdmin(user.role),
    'assets': RolePermissions.isSuperAdmin(user.role),
    'my-department': user.role == RolePermissions.manager,
    // Attendance lives in admin-only custom tables, so a plain employee can't
    // render it — hide it for them (their self-service is in My Space).
    'attendance':
        can(user, 'attendance_view') && user.role != RolePermissions.employee,
    'leave': can(user, 'leave_view'),
    'payroll': can(user, 'payroll_view'),
    'reports': can(user, 'reports_view'),
    'reminders': can(user, 'employees_view'),
    'onboarding': can(user, 'onboarding_view'),
    'notifications': can(user, 'notifications_view'),
    'settings': can(user, 'settings_view'),
    'audit': can(user, 'audit_view'),
    'google-sheets': can(user, 'googleSheets_view'),
    'google-drive': can(user, 'googleSheets_view'),
  };
}
