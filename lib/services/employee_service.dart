import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants/app_constants.dart';
import '../models/employee_model.dart';
import '../repositories/employee_repository.dart';
import 'audit_service.dart';
import 'employee_user_link_service.dart';

class EmployeeService {
  EmployeeService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    EmployeeRepository? employeeRepository,
    EmployeeUserLinkService? linkService,
    AuditService? audit,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _employees = employeeRepository ?? EmployeeRepository(),
        _linkService = linkService ?? EmployeeUserLinkService(),
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final EmployeeRepository _employees;
  final EmployeeUserLinkService _linkService;
  final AuditService _audit;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.employeesCollection);

  Stream<List<EmployeeModel>> watchEmployees({
    String? departmentId,
  }) {
    Query<Map<String, dynamic>> query =
        _collection.orderBy('createdAt', descending: true);
    if (departmentId != null) {
      query = query.where('departmentId', isEqualTo: departmentId);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) => EmployeeModel.fromMap(d.id, d.data()))
        .toList());
  }

  Future<EmployeeModel?> getEmployee(String id) async =>
      _employees.getById(id);

  Future<String> createEmployee(
    EmployeeModel employee, {
    required String userId,
  }) async {
    final data = employee.toMap();
    data['email'] = employee.email.trim().toLowerCase();
    final employeeId = await _employees.create(data);

    await _linkService.linkEmployeeToUser(
      employeeId: employeeId,
      email: employee.email,
    );

    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'employees',
      targetId: employeeId,
    );
    return employeeId;
  }

  Future<void> updateEmployee(
    EmployeeModel employee, {
    required String userId,
    bool relinkIfEmailChanged = true,
  }) async {
    final data = employee.toMap();
    data['email'] = employee.email.trim().toLowerCase();
    await _employees.update(employee.id, data);

    if (relinkIfEmailChanged) {
      await _linkService.linkEmployeeToUser(
        employeeId: employee.id,
        email: employee.email,
      );
    }

    await _audit.log(
      userId: userId,
      action: 'edit',
      module: 'employees',
      targetId: employee.id,
    );
  }

  /// Bulk-import employees parsed from a Google Sheet.
  ///
  /// Rows whose email already exists are skipped (no duplicates). Rows without
  /// an email are matched by full name instead. Returns how many were created
  /// and how many skipped as duplicates.
  Future<({int created, int duplicates})> importEmployees(
    List<EmployeeModel> employees, {
    required String userId,
  }) async {
    final existing = await _collection.get();
    final existingEmails = <String>{};
    final existingNames = <String>{};
    for (final doc in existing.docs) {
      final e = EmployeeModel.fromMap(doc.id, doc.data());
      if (e.email.trim().isNotEmpty) {
        existingEmails.add(e.email.trim().toLowerCase());
      }
      existingNames.add(e.fullName.trim().toLowerCase());
    }

    var created = 0;
    var duplicates = 0;

    for (final emp in employees) {
      final email = emp.email.trim().toLowerCase();
      final name = emp.fullName.trim().toLowerCase();

      final isDuplicate = email.isNotEmpty
          ? existingEmails.contains(email)
          : existingNames.contains(name);
      if (isDuplicate) {
        duplicates++;
        continue;
      }

      await createEmployee(emp, userId: userId);
      created++;
      if (email.isNotEmpty) existingEmails.add(email);
      existingNames.add(name);
    }

    return (created: created, duplicates: duplicates);
  }

  /// Upsert employees parsed from a sheet (for auto-sync).
  ///
  /// New rows are created; existing employees (matched by email, else by full
  /// name) are updated only when a synced field actually changed. Returns the
  /// number created and updated.
  Future<({int created, int updated})> upsertEmployees(
    List<EmployeeModel> employees, {
    required String userId,
  }) async {
    final existing = await _collection.get();
    final byEmail = <String, EmployeeModel>{};
    final byName = <String, EmployeeModel>{};
    for (final doc in existing.docs) {
      final e = EmployeeModel.fromMap(doc.id, doc.data());
      if (e.email.trim().isNotEmpty) {
        byEmail[e.email.trim().toLowerCase()] = e;
      }
      byName[e.fullName.trim().toLowerCase()] = e;
    }

    var created = 0;
    var updated = 0;

    for (final emp in employees) {
      final email = emp.email.trim().toLowerCase();
      final name = emp.fullName.trim().toLowerCase();
      final match = email.isNotEmpty ? byEmail[email] : byName[name];

      if (match == null) {
        await createEmployee(emp, userId: userId);
        created++;
        continue;
      }

      // Update only if a synced field changed.
      final changed = match.departmentName != emp.departmentName ||
          match.position != emp.position ||
          match.salary != emp.salary ||
          match.phone != emp.phone ||
          match.cnic != emp.cnic;
      if (!changed) continue;

      await _employees.update(match.id, {
        'departmentName': emp.departmentName,
        'position': emp.position,
        'salary': emp.salary,
        'phone': emp.phone,
        'cnic': emp.cnic,
        'updatedAt': DateTime.now(),
      });
      updated++;
    }

    return (created: created, updated: updated);
  }

  Future<void> deleteEmployee(String id, {required String userId}) async {
    await _collection.doc(id).delete();
    await _audit.log(
      userId: userId,
      action: 'delete',
      module: 'employees',
      targetId: id,
    );
  }

  /// Reusable: links employee ↔ user when emails match.
  Future<String?> linkEmployeeToUser({
    required String employeeId,
    required String email,
  }) =>
      _linkService.linkEmployeeToUser(
        employeeId: employeeId,
        email: email,
      );

  Future<String> uploadFile(String path, Uint8List bytes, {String? contentType}) async {
    final ref = _storage.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType ?? 'application/octet-stream'),
    );
    return await ref.getDownloadURL();
  }

  Future<int> getEmployeeCount() async {
    final snap = await _collection
        .where('status', isEqualTo: EmployeeStatus.active.name)
        .count()
        .get();
    return snap.count ?? 0;
  }
}
