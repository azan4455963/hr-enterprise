import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handled when app is in background; FCM displays notification automatically on mobile.
}

class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  CollectionReference<Map<String, dynamic>> get _tokens =>
      _firestore.collection(AppConstants.fcmTokensCollection);

  Future<void> initialize() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (_) {},
    );

    await _messaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
  }

  Future<void> saveTokenForUser(String userId) async {
    if (kIsWeb) return;
    final token = await _messaging.getToken();
    if (token == null) return;
    await _tokens.doc(userId).set({
      'token': token,
      'userId': userId,
      'updatedAt': DateTime.now(),
    });
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hr_enterprise',
          'HR Enterprise',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    await _notificationService.send(
      title: notification.title ?? 'Notification',
      body: notification.body ?? '',
      type: NotificationType.alert,
      userId: message.data['userId'] as String?,
      data: message.data,
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    // Navigation handled by app shell listening to notification taps if needed.
  }

  /// Creates in-app notification and stores for role (admin broadcast uses null userId).
  Future<void> notifyRole({
    required String title,
    required String body,
    required NotificationType type,
    String? userId,
    List<String>? targetRoles,
  }) async {
    await _notificationService.send(
      title: title,
      body: body,
      type: type,
      userId: userId,
      data: targetRoles != null ? {'targetRoles': targetRoles} : null,
    );
  }
}
