import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/department_model.dart';
import 'audit_service.dart';

/// CRUD for departments. Every change is written to the audit log so the
/// admin can see who did what (also covers director activity history).
class DepartmentService {
  DepartmentService({FirebaseFirestore? firestore, AuditService? audit})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

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

  /// Assign the directors (managers) of a department. Admin-only.
  Future<void> setDirectors(String id,
      {required List<String> directorIds, required String userId}) async {
    await _collection.doc(id).update({'directorIds': directorIds});
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'departments',
      targetId: id,
      details: {'directorIds': directorIds},
    );
  }
}
