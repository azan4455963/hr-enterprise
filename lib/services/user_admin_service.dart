import '../core/constants/permissions.dart';
import '../repositories/user_repository.dart';
import 'audit_service.dart';

/// Admin-only user management: change roles, scope directors, enable/disable.
class UserAdminService {
  UserAdminService({UserRepository? userRepository, AuditService? audit})
      : _users = userRepository ?? UserRepository(),
        _audit = audit ?? AuditService();

  final UserRepository _users;
  final AuditService _audit;

  /// Set a user's role. For a Director (manager) pass [departments].
  Future<void> setRole({
    required String uid,
    required String role,
    List<String> departments = const [],
    required String adminId,
  }) async {
    final data = <String, dynamic>{
      'role': role,
      'permissions': role == RolePermissions.superAdmin
          ? <String>['*']
          : <String>[], // others use role defaults
    };
    if (role == RolePermissions.manager) {
      data['managedDepartments'] = departments;
      data['departmentName'] = departments.isNotEmpty ? departments.first : null;
    } else {
      data['managedDepartments'] = <String>[];
      data['departmentName'] = null;
    }

    await _users.updateUser(uid, data);
    await _audit.log(
      userId: adminId,
      action: 'update',
      module: 'users',
      targetId: uid,
      details: {'role': role, 'departments': departments},
    );
  }

  /// Enable or disable a user account.
  Future<void> setActive({
    required String uid,
    required bool active,
    required String adminId,
  }) async {
    await _users.updateUser(uid, {'isActive': active});
    await _audit.log(
      userId: adminId,
      action: 'update',
      module: 'users',
      targetId: uid,
      details: {'isActive': active},
    );
  }
}
