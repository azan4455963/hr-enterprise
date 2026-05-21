import 'package:equatable/equatable.dart';

enum NotificationType {
  alert,
  attendance,
  leave,
  announcement,
  payroll,
  system,
}

class AppNotificationModel extends Equatable {
  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.userId,
    this.isRead = false,
    this.data,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? userId;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime? createdAt;

  factory AppNotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return AppNotificationModel(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'alert'),
        orElse: () => NotificationType.alert,
      ),
      userId: map['userId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      data: map['data'] as Map<String, dynamic>?,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type.name,
        'userId': userId,
        'isRead': isRead,
        'data': data,
        'createdAt': createdAt ?? DateTime.now(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, title, isRead];
}
