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
    await _users.updateUser(directorUid, {
      'role': RolePermissions.manager,
      'departmentId': departmentId,
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
      details: {'assignedDirector': directorUid},
    );
  }

  /// Remove a Director: reverts the user to a regular employee and unscopes.
  Future<void> removeDirector(
    String departmentId, {
    required String directorUid,
    required String adminId,
  }) async {
    await _users.updateUser(directorUid, {
      'role': RolePermissions.employee,
      'departmentId': null,
      'permissions': <String>[],
    });
    await _collection.doc(departmentId).update({
      'directorIds': FieldValue.arrayRemove([directorUid]),
    });
    await _audit.log(
      userId: adminId,
      action: 'update',
      module: 'departments',
      targetId: departmentId,
      details: {'removedDirector': directorUid},
    );
  }
}
