import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/permissions.dart';
import '../models/department_model.dart';
import '../repositories/user_repository.dart';
import 'audit_service.dart';

/// CRUD for departments. Every change is written to the audit log so the
/// admin can see who did what (also covers director activity history).
class DepartmentService {
  DepartmentService({
    FirebaseFirestore? firestore,
    AuditService? audit,
    UserRepository? userRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService(),
        _users = userRepository ?? UserRepository();

  final FirebaseFirestore _firestore;
  final AuditService _audit;
  final UserRepository _users;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('departments');

  Stream<List<DepartmentModel>> watchDepartments() {
    return _collection.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => DepartmentModel.fromMap(d.data(), d.id))
        .toList());
  }

  Future<String> create({
    required String name,
    String? description,
    required String userId,
  }) async {
    final ref = await _collection.add({
      'name': name.trim(),
      'description': description,
      'directorIds': <String>[],
      'createdAt': DateTime.now(),
      'createdBy': userId,
    });
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'departments',
      targetId: ref.id,
      details: {'name': name},
    );
    return ref.id;
  }

  Future<void> rename(String id,
      {required String name, required String userId}) async {
    await _collection.doc(id).update({'name': name.trim()});
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'departments',
      targetId: id,
      details: {'name': name},
    );
  }

  Future<void> delete(String id, {required String userId}) async {
    await _collection.doc(id).delete();
    await _audit.log(
      userId: userId,
      action: 'delete',
      module: 'departments',
      targetId: id,
    );
  }

  /// Make a user a Director of this department: sets their role to `manager`
  /// and scopes them to this department. Admin-only.
  Future<void> assignDirector(
    String departmentId, {
    required String directorUid,
    required String adminId,
  }) async {
    // Capture the department name so the director can be scoped to it.
    final snap = await _collection.doc(departmentId).get();
    final deptName = (snap.data()?['name'] as String?)?.trim() ?? '';

    // Add this department to the director's managed list (can be many).
    await _users.updateUser(directorUid, {
      'role': RolePermissions.manager,
      'departmentName': deptName, // primary (back-compat)
      'managedDepartments': FieldValue.arrayUnion([deptName]),
      'permissions': <String>[], // use role defaults
    });
    await _collection.doc(departmentId).update({
      'directorIds': FieldValue.arrayUnion([directorUid]),
    });
    await _audit.log(
      userId: adminId,
      action: 'update',
      module: 'departments',
      targetId: departmentId,
      details: {'assignedDirector': directorUid, 'department': deptName},
    );
  }

  /// Remove a director from THIS department. If it was their only department,
  /// they revert to a regular employee.
  Future<void> removeDirector(
    String departmentId, {
    required String directorUid,
    required String adminId,
  }) async {
    final snap = await _collection.doc(departmentId).get();
    final deptName = (snap.data()?['name'] as String?)?.trim() ?? '';

    final user = await _users.getById(directorUid);
    final remaining = [...(user?.managedDepartments ?? const <String>[])]
      ..remove(deptName);

    if (remaining.isEmpty) {
      // No departments left → back to a regular employee.
      await _users.updateUser(directorUid, {
        'role': RolePermissions.employee,
        'departmentName': null,
        'managedDepartments': <String>[],
        'permissions': <String>[],
      });
    } else {
      await _users.updateUser(directorUid, {
        'managedDepartments': remaining,
        'departmentName': remaining.first,
      });
    }
    await _collection.doc(departmentId).update({
      'directorIds': FieldValue.arrayRemove([directorUid]),
    });
    await _audit.log(
      userId: adminId,
      action: 'update',
      module: 'departments',
      targetId: departmentId,
      details: {'removedDirector': directorUid, 'department': deptName},
    );
  }
}
