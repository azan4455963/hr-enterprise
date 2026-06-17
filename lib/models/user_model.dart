import 'package:equatable/equatable.dart';

import '../core/constants/permissions.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.departmentId,
    this.departmentName,
    this.managedDepartments = const [],
    this.employeeId,
    this.companyId = 'default_company',
    this.permissions = const [],
    this.isActive = true,
    this.createdAt,
    this.lastLoginAt,
  });

  final String id;
  final String email;
  final String role;
  final String? displayName;
  final String? photoUrl;
  final String? departmentId;

  /// For a Director (manager): the department they manage (by name).
  /// Kept for back-compat; [managedDepartments] is the source of truth.
  final String? departmentName;

  /// Departments a Director manages (can be one or many).
  final List<String> managedDepartments;
  final String? employeeId;

  /// Effective list of departments this user is scoped to (Director).
  List<String> get departments => managedDepartments.isNotEmpty
      ? managedDepartments
      : (departmentName != null && departmentName!.isNotEmpty
          ? [departmentName!]
          : const []);
  final String companyId;
  final List<String> permissions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  bool hasPermission(String permission) => RolePermissions.userHasPermission(
        role: role,
        storedPermissions: permissions,
        permission: permission,
      );

  bool canViewSalary() =>
      RolePermissions.isSuperAdmin(role) ||
      (RolePermissions.isRoleEnabled(role) &&
          hasPermission('payroll_view'));

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: (map['email'] as String? ?? '').trim().toLowerCase(),
      role: map['role'] as String? ?? RolePermissions.employee,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      departmentId: map['departmentId'] as String?,
      departmentName: map['departmentName'] as String?,
      managedDepartments:
          List<String>.from(map['managedDepartments'] as List? ?? const []),
      employeeId: map['employeeId'] as String?,
      companyId: map['companyId'] as String? ?? 'default_company',
      permissions: List<String>.from(map['permissions'] as List? ?? []),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt']),
      lastLoginAt: _parseDate(map['lastLoginAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email.trim().toLowerCase(),
        'role': role,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'departmentId': departmentId,
        'departmentName': departmentName,
        'managedDepartments': managedDepartments,
        'employeeId': employeeId,
        'companyId': companyId,
        'permissions': permissions,
        'isActive': isActive,
        'createdAt': createdAt,
        'lastLoginAt': lastLoginAt,
      };

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    String? role,
    List<String>? permissions,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id,
      email: email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      departmentId: departmentId,
      employeeId: employeeId,
      companyId: companyId,
      permissions: permissions ?? this.permissions,
      isActive: isActive,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props =>
      [id, email, role, departmentId, employeeId, permissions];
}
