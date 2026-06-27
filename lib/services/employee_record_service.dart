import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  /// Fixed doc id for the published attendance snapshot (one per employee).
  static const attendanceSummaryId = 'attendance_summary';

  /// Publish (upsert) one employee's attendance snapshot so the linked employee
  /// can read it on their My Space. Marked visibleToEmployee so the existing
  /// security rule allows the employee to read just this record.
  Future<void> publishAttendanceSummary({
    required String employeeId,
    required int present,
    required int late,
    required int leave,
    required int absent,
    required String datesText,
    required String userId,
  }) async {
    await _ref(employeeId).doc(attendanceSummaryId).set({
      'title': 'Attendance Summary',
      'category': 'attendance',
      'visibleToEmployee': true,
      'fields': [
        {'label': 'Present', 'value': '$present'},
        {'label': 'Late', 'value': '$late'},
        {'label': 'Leave', 'value': '$leave'},
        {'label': 'Absent', 'value': '$absent'},
        {
          'label': 'Updated',
          'value': DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()),
        },
      ],
      'note': datesText,
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Read one employee's published attendance snapshot (admin or the linked
  /// employee themselves).
  Stream<EmployeeRecordModel?> watchAttendanceSummary(String employeeId) {
    return _ref(employeeId).doc(attendanceSummaryId).snapshots().map(
        (d) => d.exists ? EmployeeRecordModel.fromMap(d.data()!, d.id) : null);
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
