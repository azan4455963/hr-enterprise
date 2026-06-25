import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_document_model.dart';
import 'audit_service.dart';
import 'storage_service.dart';

/// Manages files attached to an employee: uploads bytes to Firebase Storage and
/// keeps metadata under `employees/{employeeId}/documents`.
class EmployeeDocumentService {
  EmployeeDocumentService({
    FirebaseFirestore? firestore,
    StorageService? storage,
    AuditService? audit,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? StorageService(),
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final StorageService _storage;
  final AuditService _audit;

  CollectionReference<Map<String, dynamic>> _ref(String employeeId) => _firestore
      .collection('employees')
      .doc(employeeId)
      .collection('documents');

  Stream<List<EmployeeDocumentModel>> watch(String employeeId) {
    return _ref(employeeId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => EmployeeDocumentModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> upload(
    String employeeId, {
    required Uint8List bytes,
    required String fileName,
    String category = 'General',
    String? contentType,
    required String userId,
  }) async {
    final url = await _storage.uploadDocument(employeeId, bytes, fileName);
    await _ref(employeeId).add({
      'name': fileName,
      'url': url,
      'category': category,
      'contentType': contentType,
      'size': bytes.length,
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': userId,
    });
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'employee_documents',
      targetId: '$employeeId/$fileName',
      details: {'name': fileName, 'category': category},
    );
  }

  Future<void> delete(String employeeId, EmployeeDocumentModel doc,
      {required String userId}) async {
    await _storage.deleteByUrl(doc.url);
    await _ref(employeeId).doc(doc.id).delete();
    await _audit.log(
      userId: userId,
      action: 'delete',
      module: 'employee_documents',
      targetId: '$employeeId/${doc.id}',
      details: {'name': doc.name},
    );
  }
}
