import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/payroll_model.dart';

class PayrollService {
  PayrollService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.payrollCollection);

  Stream<List<PayrollModel>> watchPayroll({int? month, int? year}) {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          var list = snap.docs
              .map((d) => PayrollModel.fromMap(d.id, d.data()))
              .toList();
          if (month != null) {
            list = list.where((p) => p.month == month).toList();
          }
          if (year != null) {
            list = list.where((p) => p.year == year).toList();
          }
          return list;
        });
  }

  /// One employee's payroll, newest month first. Uses a constrained query so it
  /// works under the per-employee payroll read rule (employee self-service).
  Stream<List<PayrollModel>> watchForEmployee(String employeeId) {
    return _collection
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => PayrollModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        return byYear != 0 ? byYear : b.month.compareTo(a.month);
      });
      return list;
    });
  }

  Future<String> createPayroll(PayrollModel payroll) async {
    final ref = await _collection.add(payroll.toMap());
    return ref.id;
  }

  /// Bulk-create payroll records (e.g. generating a whole month) in one batch.
  /// Returns the number written.
  Future<int> createMany(List<PayrollModel> records) async {
    if (records.isEmpty) return 0;
    final batch = _firestore.batch();
    for (final r in records) {
      batch.set(_collection.doc(), r.toMap());
    }
    await batch.commit();
    return records.length;
  }

  /// Overwrite an existing record (recomputes netSalary via toMap()).
  Future<void> update(PayrollModel payroll) async {
    await _collection.doc(payroll.id).update(payroll.toMap());
  }

  Future<void> updateStatus(String id, PaymentStatus status) async {
    await _collection.doc(id).update({
      'status': status.name,
      'paidAt': status == PaymentStatus.paid ? DateTime.now() : null,
    });
  }

  Future<double> getMonthlyPayrollTotal(int month, int year) async {
    final records = await watchPayroll(month: month, year: year).first;
    var total = 0.0;
    for (final p in records) {
      total += p.calculatedNet;
    }
    return total;
  }
}
