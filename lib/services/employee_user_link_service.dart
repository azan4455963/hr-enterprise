import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/app_exception.dart';
import '../repositories/employee_repository.dart';
import '../repositories/user_repository.dart';

/// Links `employees/{employeeId}` ↔ `users/{uid}` by matching email.
class EmployeeUserLinkService {
  EmployeeUserLinkService({
    UserRepository? userRepository,
    EmployeeRepository? employeeRepository,
    FirebaseFirestore? firestore,
  })  : _users = userRepository ?? UserRepository(),
        _employees = employeeRepository ?? EmployeeRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final UserRepository _users;
  final EmployeeRepository _employees;
  final FirebaseFirestore _firestore;

  /// If a user exists with the same email as the employee, links both documents.
  ///
  /// - `users/{uid}.employeeId` = [employeeId]
  /// - `employees/{employeeId}.userId` = [uid]
  ///
  /// Returns linked user id, or null if no matching user.
  Future<String?> linkEmployeeToUser({
    required String employeeId,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw AppException('Employee email is required for linking.');
    }

    final user = await _users.findByEmail(normalizedEmail);
    if (user == null) return null;

    await _linkBidirectional(
      userId: user.id,
      employeeId: employeeId,
    );
    return user.id;
  }

  Future<void> _linkBidirectional({
    required String userId,
    required String employeeId,
  }) async {
    final batch = _firestore.batch();

    final userRef = _users.doc(userId);
    batch.update(userRef, {
      'employeeId': employeeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final employeeRef = _employees.doc(employeeId);
    batch.update(employeeRef, {
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Removes link from both sides.
  Future<void> unlinkEmployeeFromUser({
    required String employeeId,
    required String userId,
  }) async {
    final batch = _firestore.batch();
    batch.update(_users.doc(userId), {
      'employeeId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_employees.doc(employeeId), {
      'userId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
