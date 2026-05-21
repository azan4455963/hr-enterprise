import 'package:equatable/equatable.dart';

class AuditLogModel extends Equatable {
  const AuditLogModel({
    required this.id,
    required this.userId,
    required this.action,
    required this.module,
    this.targetId,
    this.details,
    this.ipAddress,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String action;
  final String module;
  final String? targetId;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final DateTime? createdAt;

  factory AuditLogModel.fromMap(String id, Map<String, dynamic> map) {
    return AuditLogModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      action: map['action'] as String? ?? '',
      module: map['module'] as String? ?? '',
      targetId: map['targetId'] as String?,
      details: map['details'] as Map<String, dynamic>?,
      ipAddress: map['ipAddress'] as String?,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'action': action,
        'module': module,
        'targetId': targetId,
        'details': details,
        'ipAddress': ipAddress,
        'createdAt': createdAt ?? DateTime.now(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, userId, action, module];
}
