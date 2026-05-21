import 'package:equatable/equatable.dart';

class AttendanceQrSessionModel extends Equatable {
  const AttendanceQrSessionModel({
    required this.id,
    required this.sessionToken,
    required this.companyId,
    required this.createdBy,
    required this.expiresAt,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String sessionToken;
  final String companyId;
  final String createdBy;
  final DateTime expiresAt;
  final bool isActive;
  final DateTime? createdAt;

  bool get isValid =>
      isActive && DateTime.now().isBefore(expiresAt);

  factory AttendanceQrSessionModel.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceQrSessionModel(
      id: id,
      sessionToken: map['sessionToken'] as String? ?? '',
      companyId: map['companyId'] as String? ?? 'default_company',
      createdBy: map['createdBy'] as String? ?? '',
      expiresAt: _parseDate(map['expiresAt']) ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'sessionToken': sessionToken,
        'companyId': companyId,
        'createdBy': createdBy,
        'expiresAt': expiresAt,
        'isActive': isActive,
        'createdAt': createdAt ?? DateTime.now(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, sessionToken, isActive];
}
