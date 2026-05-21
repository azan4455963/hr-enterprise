import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/employee_model.dart';

/// Firestore data access for `employees/{employeeId}`.
class EmployeeRepository {
  EmployeeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.employeesCollection);

  DocumentReference<Map<String, dynamic>> doc(String employeeId) =>
      _collection.doc(employeeId);

  Future<EmployeeModel?> getById(String employeeId) async {
    final snap = await doc(employeeId).get();
    if (!snap.exists || snap.data() == null) return null;
    return EmployeeModel.fromMap(snap.id, snap.data()!);
  }

  Future<String> create(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _collection.add(data);
    return ref.id;
  }

  Future<void> update(String employeeId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await doc(employeeId).update(data);
  }

  Future<void> setUserId(String employeeId, String userId) async {
    await doc(employeeId).update({
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearUserId(String employeeId) async {
    await doc(employeeId).update({
      'userId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
