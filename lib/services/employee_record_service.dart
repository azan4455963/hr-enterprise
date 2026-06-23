import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_record_model.dart';
import 'audit_service.dart';

/// CRUD for free-form per-employee records under
/// `employees/{employeeId}/records`. Everything is keyed by the employee id.
class EmployeeRecordService {
  EmployeeRecordService({FirebaseFirestore? firestore, AuditService? audit})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

  CollectionReference<Map<String, dynamic>> _ref(String employeeId) =>
      _firestore.collection('employees').doc(employeeId).collection('records');

  Stream<List<EmployeeRecordModel>> watch(String employeeId) {
    return _ref(employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => EmployeeRecordModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> add(String employeeId, EmployeeRecordModel record,
      {required String userId}) async {
    final ref = await _ref(employeeId).add(record.toMap());
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'employee_records',
      targetId: '$employeeId/${ref.id}',
      details: {'title': record.title, 'category': record.category},
    );
  }

  Future<void> update(String employeeId, EmployeeRecordModel record,
      {required String userId}) async {
    final map = record.toMap()..remove('createdAt');
    await _ref(employeeId).doc(record.id).update(map);
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'employee_records',
      targetId: '$employeeId/${record.id}',
      details: {'title': record.title},
    );
  }

  Future<void> delete(String employeeId, String recordId,
      {required String userId}) async {
    await _ref(employeeId).doc(recordId).delete();
    await _audit.log(
      userId: userId,
      action: 'delete',
      module: 'employee_records',
      targetId: '$employeeId/$recordId',
    );
  }
}
