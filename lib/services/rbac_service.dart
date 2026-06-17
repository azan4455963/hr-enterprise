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
    'dashboard': can(user, 'dashboard_view'),
    'employees': can(user, 'employees_view'),
    'employee-search': can(user, 'employees_view'),
    'departments': can(user, 'departments_manage'),
    'my-department': user.role == RolePermissions.manager,
    'attendance': can(user, 'attendance_view'),
    'leave': can(user, 'leave_view'),
    'payroll': can(user, 'payroll_view'),
    'reports': can(user, 'reports_view'),
    'onboarding': can(user, 'onboarding_view'),
    'notifications': can(user, 'notifications_view'),
    'settings': can(user, 'settings_view'),
    'audit': can(user, 'audit_view'),
    'google-sheets': can(user, 'googleSheets_view'),
    'google-drive': can(user, 'googleSheets_view'),
  };
}
