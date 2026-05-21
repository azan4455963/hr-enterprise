import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/audit_log_model.dart';

class AuditService {
  AuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.auditLogsCollection);

  Future<void> log({
    required String userId,
    required String action,
    required String module,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    final log = AuditLogModel(
      id: '',
      userId: userId,
      action: action,
      module: module,
      targetId: targetId,
      details: details,
      createdAt: DateTime.now(),
    );
    await _collection.add(log.toMap());
  }

  Stream<List<AuditLogModel>> watchLogs({int limit = 50}) {
    return _collection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditLogModel.fromMap(d.id, d.data()))
            .toList());
  }
}
