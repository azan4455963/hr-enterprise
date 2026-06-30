import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/utils/firestore_parse.dart';

enum AccessRequestStatus { pending, approved, rejected }

/// A user's request to be granted one feature permission. An admin approves it
/// (which adds the permission to the user) or rejects it.
class AccessRequestModel extends Equatable {
  const AccessRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.permission,
    required this.moduleLabel,
    required this.permLabel,
    this.status = AccessRequestStatus.pending,
    this.requestedAt,
    this.decidedBy,
    this.decidedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String permission; // permission key, e.g. payroll_view
  final String moduleLabel; // e.g. "Payroll"
  final String permLabel; // e.g. "View"
  final AccessRequestStatus status;
  final DateTime? requestedAt;
  final String? decidedBy;
  final DateTime? decidedAt;

  factory AccessRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return AccessRequestModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userEmail: map['userEmail'] as String? ?? '',
      permission: map['permission'] as String? ?? '',
      moduleLabel: map['moduleLabel'] as String? ?? '',
      permLabel: map['permLabel'] as String? ?? '',
      status: AccessRequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'pending'),
        orElse: () => AccessRequestStatus.pending,
      ),
      requestedAt: parseFirestoreDate(map['requestedAt']),
      decidedBy: map['decidedBy'] as String?,
      decidedAt: parseFirestoreDate(map['decidedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'permission': permission,
        'moduleLabel': moduleLabel,
        'permLabel': permLabel,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, userId, permission, status];
}
