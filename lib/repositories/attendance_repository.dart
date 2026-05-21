import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/attendance_model.dart';

/// Firestore data access for `attendance/{id}`.
/// Canonical fields: employeeId, status, timestamp, method.
class AttendanceRepository {
  AttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.attendanceCollection);

  /// Writes attendance using employeeId only (never email).
  Future<String> createRecord({
    required String employeeId,
    required String status,
    required DateTime timestamp,
    required String method,
    String? employeeName,
    DateTime? date,
    DateTime? checkIn,
    DateTime? checkOut,
  }) async {
    final day = date ?? DateTime(timestamp.year, timestamp.month, timestamp.day);
    final ref = await _collection.add({
      'employeeId': employeeId,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'method': method,
      'attendanceMethod': method,
      'employeeName': employeeName,
      'date': Timestamp.fromDate(day),
      if (checkIn != null) 'checkIn': Timestamp.fromDate(checkIn),
      if (checkOut != null) 'checkOut': Timestamp.fromDate(checkOut),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateRecord(
    String id, {
    required Map<String, dynamic> data,
  }) async {
    await _collection.doc(id).update(data);
  }

  Future<DocumentReference<Map<String, dynamic>>?> findTodayRecord(
    String employeeId,
  ) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final snap = await _collection
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.reference;
  }

  Stream<List<AttendanceModel>> watchToday() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return _collection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<AttendanceModel>> watchRecent({int days = 30}) {
    final start = DateTime.now().subtract(Duration(days: days));
    return _collection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceModel.fromMap(d.id, d.data()))
            .toList());
  }
}
