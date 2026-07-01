import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/firestore_parse.dart';
import '../models/user_model.dart';

/// Firestore data access for `users/{uid}`.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.usersCollection);

  DocumentReference<Map<String, dynamic>> doc(String uid) => _collection.doc(uid);

  Future<UserModel?> getById(String uid) async {
    final snap = await doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserModel.fromMap(snap.id, snap.data()!);
  }

  Stream<UserModel?> watchById(String uid) {
    return doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<UserModel>> watchAll() {
    return _collection.snapshots().map((snap) =>
        snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList());
  }

  Future<UserModel?> findByEmail(String email) async {
    final snap = await _collection
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return UserModel.fromMap(doc.id, doc.data());
  }

  Future<void> setUser(String uid, Map<String, dynamic> data, {bool merge = false}) async {
    await doc(uid).set(data, SetOptions(merge: merge));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await doc(uid).update(data);
  }

  Future<void> deleteUser(String uid) async {
    await doc(uid).delete();
  }

  Future<bool> exists(String uid) async {
    final snap = await doc(uid).get();
    return snap.exists;
  }

  /// Returns linked employeeId or null.
  Future<String?> getEmployeeId(String uid) async {
    final user = await getById(uid);
    final id = user?.employeeId;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Always fetch role from Firestore (never cache-only in UI).
  Future<String?> getRole(String uid) async {
    final user = await getById(uid);
    return user?.role;
  }

  static Map<String, dynamic> superAdminPayload({
    required String email,
    String? displayName,
    String? photoUrl,
  }) {
    return {
      'role': 'super_admin',
      'permissions': ['*'],
      'email': email.trim().toLowerCase(),
      'employeeId': null,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'companyId': AppConstants.companyId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> employeeUserPayload({
    required String email,
    required String role,
    required List<String> permissions,
    String? displayName,
    String? photoUrl,
    String? employeeId,
  }) {
    return {
      'role': role,
      'permissions': permissions,
      'email': email.trim().toLowerCase(),
      'employeeId': employeeId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'companyId': AppConstants.companyId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? parseCreatedAt(Map<String, dynamic> map) =>
      parseFirestoreDate(map['createdAt']);
}
