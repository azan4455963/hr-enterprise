import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/permissions.dart';
import '../core/utils/app_exception.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'rbac_service.dart';

/// Business logic for users collection, roles, and super admin setup.
class UserBackendService {
  UserBackendService({
    UserRepository? userRepository,
    RbacService? rbac,
    FirebaseAuth? auth,
  })  : _users = userRepository ?? UserRepository(),
        _rbac = rbac ?? RbacService(),
        _auth = auth ?? FirebaseAuth.instance;

  final UserRepository _users;
  final RbacService _rbac;
  final FirebaseAuth _auth;

  /// Creates or overwrites `users/{uid}` as super admin (manual or post-signup).
  Future<UserModel> createSuperAdmin({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final payload = UserRepository.superAdminPayload(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
    );
    await _users.setUser(uid, payload);
    final created = await _users.getById(uid);
    if (created == null) {
      throw AppException('Failed to create super admin profile.');
    }
    return created;
  }

  /// Promotes the currently signed-in Firebase user to super admin.
  Future<UserModel> createSuperAdminForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AppException('No authenticated user.');
    }
    return createSuperAdmin(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  /// Standard employee user document after Auth signup (employeeId: null).
  Future<UserModel> createUserOnSignup({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    String role = RolePermissions.employee,
  }) async {
    final assignable =
        RolePermissions.validateAssignableRole(role) ?? RolePermissions.employee;
    final permissions = _rbac.getPermissionsForRole(assignable);
    final payload = UserRepository.employeeUserPayload(
      email: email,
      role: assignable,
      permissions: permissions,
      displayName: displayName,
      photoUrl: photoUrl,
      employeeId: null,
    );
    await _users.setUser(uid, payload);
    final created = await _users.getById(uid);
    if (created == null) {
      throw AppException('Failed to create user profile.');
    }
    return created;
  }

  /// Ensures profile exists after login; does not downgrade super admin.
  Future<UserModel> ensureUserProfile(User firebaseUser) async {
    final existing = await _users.getById(firebaseUser.uid);
    if (existing != null) {
      await _users.updateUser(firebaseUser.uid, {
        'lastLoginAt': DateTime.now(),
      });
      return (await _users.getById(firebaseUser.uid))!;
    }
    return createUserOnSignup(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  Future<UserModel?> getUserByUid(String uid) => _users.getById(uid);

  Stream<UserModel?> watchUserByUid(String uid) => _users.watchById(uid);

  /// Always load role from Firestore `users/{uid}`.
  Future<String> getRoleFromUid(String uid) async {
    final role = await _users.getRole(uid);
    if (role == null || role.isEmpty) {
      throw AppException('User role not found.');
    }
    return role;
  }

  /// Attendance allowed only when user is linked to an employee record.
  Future<bool> canMarkAttendance(String uid) async {
    final employeeId = await _users.getEmployeeId(uid);
    return employeeId != null;
  }

  /// Resolves employeeId for attendance; throws if not linked.
  Future<String> requireEmployeeIdForAttendance(String uid) async {
    final employeeId = await _users.getEmployeeId(uid);
    if (employeeId == null) {
      throw AppException(
        'Cannot mark attendance. Your account is not linked to an employee profile. '
        'Contact HR to link users/{uid}.employeeId.',
      );
    }
    return employeeId;
  }
}
