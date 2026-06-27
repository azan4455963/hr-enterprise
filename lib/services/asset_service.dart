import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/asset_model.dart';
import 'audit_service.dart';

/// CRUD for company assets (`assets`). Assets can be assigned to / unassigned
/// from employees.
class AssetService {
  AssetService({FirebaseFirestore? firestore, AuditService? audit})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('assets');

  Stream<List<AssetModel>> watchAll() {
    return _ref.orderBy('createdAt', descending: true).snapshots().map(
          (snap) =>
              snap.docs.map((d) => AssetModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<String> create(AssetModel asset, {required String userId}) async {
    final ref = await _ref.add(asset.toMap());
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'assets',
      targetId: ref.id,
      details: {'name': asset.name},
    );
    return ref.id;
  }

  Future<void> update(AssetModel asset, {required String userId}) async {
    await _ref.doc(asset.id).update(asset.toMap()..remove('createdAt'));
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'assets',
      targetId: asset.id,
      details: {'name': asset.name},
    );
  }

  /// Assign an asset to an employee (sets status = assigned).
  Future<void> assign(String assetId,
      {required String employeeId,
      required String employeeName,
      required String userId}) async {
    await _ref.doc(assetId).update({
      'assignedToId': employeeId,
      'assignedToName': employeeName,
      'status': AssetStatus.assigned.name,
      'assignedDate': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'assets',
      targetId: assetId,
      details: {'assignedTo': employeeName},
    );
  }

  /// Return an asset (clears the assignee, status = available).
  Future<void> unassign(String assetId, {required String userId}) async {
    await _ref.doc(assetId).update({
      'assignedToId': null,
      'assignedToName': null,
      'status': AssetStatus.available.name,
      'assignedDate': null,
    });
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'assets',
      targetId: assetId,
    );
  }

  Future<void> delete(String assetId, {required String userId}) async {
    await _ref.doc(assetId).delete();
    await _audit.log(
      userId: userId,
      action: 'delete',
      module: 'assets',
      targetId: assetId,
    );
  }
}
