import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/data_table_model.dart';
import 'audit_service.dart';

/// CRUD for custom in-app data tables (`data_tables`).
class DataTableService {
  DataTableService({FirebaseFirestore? firestore, AuditService? audit})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('data_tables');

  Stream<List<DataTableModel>> watchTables() {
    return _ref.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => DataTableModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Stream<DataTableModel?> watchTable(String id) {
    return _ref.doc(id).snapshots().map(
        (d) => d.exists ? DataTableModel.fromMap(d.data()!, d.id) : null);
  }

  Future<String> create({
    required String name,
    required String userId,
    List<String> columns = const ['Column 1'],
  }) async {
    final ref = await _ref.add({
      'name': name.trim(),
      'columns': columns,
      'rows': <Map<String, dynamic>>[],
      'createdBy': userId,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'tables',
      targetId: ref.id,
      details: {'name': name},
    );
    return ref.id;
  }

  /// Save the whole table (columns + rows). Optionally also renames it.
  Future<void> save(
    String id, {
    String? name,
    required List<String> columns,
    required List<List<String>> rows,
    required String userId,
  }) async {
    await _ref.doc(id).update({
      if (name != null) 'name': name.trim(),
      'columns': columns,
      'rows': [
        for (final r in rows) {'cells': r},
      ],
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'tables',
      targetId: id,
    );
  }

  Future<void> rename(String id,
      {required String name, required String userId}) async {
    await _ref.doc(id).update({'name': name.trim(), 'updatedAt': DateTime.now()});
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'tables',
      targetId: id,
      details: {'name': name},
    );
  }

  Future<void> delete(String id, {required String userId}) async {
    await _ref.doc(id).delete();
    await _audit.log(
      userId: userId,
      action: 'delete',
      module: 'tables',
      targetId: id,
    );
  }
}
