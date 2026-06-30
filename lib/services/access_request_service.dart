import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/permissions.dart';
import '../models/access_request_model.dart';
import '../repositories/user_repository.dart';

/// Feature-access requests: a user asks for one permission, an admin approves
/// (which grants it) or rejects. Backed by the `access_requests` collection.
class AccessRequestService {
  AccessRequestService({FirebaseFirestore? firestore, UserRepository? users})
      : _db = firestore ?? FirebaseFirestore.instance,
        _users = users ?? UserRepository();

  final FirebaseFirestore _db;
  final UserRepository _users;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('access_requests');

  Future<void> create({
    required String userId,
    required String userName,
    required String userEmail,
    required String permission,
    required String moduleLabel,
    required String permLabel,
  }) async {
    await _col.add(AccessRequestModel(
      id: '',
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      permission: permission,
      moduleLabel: moduleLabel,
      permLabel: permLabel,
    ).toCreateMap());
  }

  List<AccessRequestModel> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs
        .map((d) => AccessRequestModel.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => (b.requestedAt ?? DateTime(0))
        .compareTo(a.requestedAt ?? DateTime(0)));
    return list;
  }

  /// All pending requests (admin view). Sorted newest-first client-side so no
  /// composite index is needed.
  Stream<List<AccessRequestModel>> watchPending() => _col
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map(_sorted);

  /// One user's own requests (any status).
  Stream<List<AccessRequestModel>> watchForUser(String userId) => _col
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map(_sorted);

  /// Approve a request: grant the permission to the user, then mark it approved.
  Future<void> approve(AccessRequestModel req, String adminId) async {
    final user = await _users.getById(req.userId);
    if (user != null && !RolePermissions.isSuperAdmin(user.role)) {
      final perms = RolePermissions.resolvedPermissions(
        role: user.role,
        storedPermissions: user.permissions,
      ).toSet();
      if (!perms.contains('*')) {
        perms.add(req.permission);
        await _users.updateUser(req.userId, {'permissions': perms.toList()});
      }
    }
    await _col.doc(req.id).update({
      'status': 'approved',
      'decidedBy': adminId,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String requestId, String adminId) async {
    await _col.doc(requestId).update({
      'status': 'rejected',
      'decidedBy': adminId,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }
}
