import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/leave_model.dart';
import 'audit_service.dart';

class LeaveService {
  LeaveService({
    FirebaseFirestore? firestore,
    AuditService? audit,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.leaveCollection);

  Stream<List<LeaveRequestModel>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LeaveRequestModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<LeaveRequestModel>> watchByEmployee(String employeeId) {
    return _collection
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LeaveRequestModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<LeaveRequestModel>> watchPending() {
    return _collection
        .where('status', isEqualTo: LeaveStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LeaveRequestModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<String> createRequest(LeaveRequestModel request) async {
    final ref = await _collection.add(request.toMap());
    return ref.id;
  }

  Future<void> approve(String id, String approvedBy) async {
    await _collection.doc(id).update({
      'status': LeaveStatus.approved.name,
      'approvedBy': approvedBy,
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: approvedBy,
      action: 'approve',
      module: 'leave',
      targetId: id,
    );
  }

  Future<void> reject(
    String id,
    String rejectedBy, {
    String? reason,
  }) async {
    await _collection.doc(id).update({
      'status': LeaveStatus.rejected.name,
      'approvedBy': rejectedBy,
      'rejectionReason': reason,
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: rejectedBy,
      action: 'reject',
      module: 'leave',
      targetId: id,
    );
  }
}
