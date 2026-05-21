import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.notificationsCollection);

  Stream<List<AppNotificationModel>> watchForUser(UserModel user) {
    return _collection
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      final all = snap.docs
          .map((d) => AppNotificationModel.fromMap(d.id, d.data()))
          .toList();
      return all.where((n) {
        if (n.userId == null) {
          final roles = n.data?['targetRoles'] as List?;
          if (roles == null) return true;
          return roles.contains(user.role);
        }
        return n.userId == user.id || n.userId == user.employeeId;
      }).toList();
    });
  }

  Future<void> send({
    required String title,
    required String body,
    required NotificationType type,
    String? userId,
    List<String>? targetRoles,
    Map<String, dynamic>? data,
  }) async {
    final payload = AppNotificationModel(
      id: '',
      title: title,
      body: body,
      type: type,
      userId: userId,
      data: {
        ...?data,
        if (targetRoles != null) 'targetRoles': targetRoles,
      },
      createdAt: DateTime.now(),
    ).toMap();
    await _collection.add(payload);
  }

  Future<void> markAsRead(String id) async {
    await _collection.doc(id).update({'isRead': true});
  }

  Future<void> markAllRead(UserModel user) async {
    final items = await watchForUser(user).first;
    final batch = _firestore.batch();
    for (final n in items.where((i) => !i.isRead)) {
      batch.update(_collection.doc(n.id), {'isRead': true});
    }
    await batch.commit();
  }
}
