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
    'my-attendance': user.role == RolePermissions.employee,
    'my-salary': user.role == RolePermissions.employee,
    'employees': can(user, 'employees_view'),
    'employee-search': can(user, 'employees_view'),
    'employee-record': can(user, 'employees_view'),
    'departments': can(user, 'departments_manage'),
    // Users & Roles and the Activity log stay super-admin only so a grant can
    // never escalate someone into managing other people's access.
    'users': RolePermissions.isSuperAdmin(user.role),
    'activity': RolePermissions.isSuperAdmin(user.role),
    // Grantable per-user: an admin can hand Tables / Assets access to anyone.
    'tables': can(user, 'tables_manage'),
    'assets': can(user, 'assets_manage'),
    'my-department': user.role == RolePermissions.manager,
    // The admin Attendance page is a management view — gated on attendance_edit
    // so plain employees (view-only, self-service in My Space) don't see it, but
    // an admin can grant the page to a director or any user.
    'attendance': can(user, 'attendance_edit'),
    'leave': can(user, 'leave_view'),
    // Everyone can chat (recipients are scoped by role in chatRecipientsProvider).
    'messages': true,
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
