import 'package:equatable/equatable.dart';

class CompanySettingsModel extends Equatable {
  const CompanySettingsModel({
    required this.id,
    required this.companyName,
    this.workStartHour = 9,
    this.workStartMinute = 0,
    this.lateAfterMinutes = 15,
    this.workEndHour = 18,
    this.workEndMinute = 0,
    this.biometricEnabled = false,
    this.updatedAt,
  });

  final String id;
  final String companyName;
  final int workStartHour;
  final int workStartMinute;
  final int lateAfterMinutes;
  final int workEndHour;
  final int workEndMinute;
  final bool biometricEnabled;
  final DateTime? updatedAt;

  factory CompanySettingsModel.defaults(String companyId) {
    return CompanySettingsModel(
      id: companyId,
      companyName: 'HR Enterprise',
    );
  }

  factory CompanySettingsModel.fromMap(String id, Map<String, dynamic> map) {
    return CompanySettingsModel(
      id: id,
      companyName: map['companyName'] as String? ?? 'HR Enterprise',
      workStartHour: map['workStartHour'] as int? ?? 9,
      workStartMinute: map['workStartMinute'] as int? ?? 0,
      lateAfterMinutes: map['lateAfterMinutes'] as int? ?? 15,
      workEndHour: map['workEndHour'] as int? ?? 18,
      workEndMinute: map['workEndMinute'] as int? ?? 0,
      biometricEnabled: map['biometricEnabled'] as bool? ?? false,
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'companyName': companyName,
        'workStartHour': workStartHour,
        'workStartMinute': workStartMinute,
        'lateAfterMinutes': lateAfterMinutes,
        'workEndHour': workEndHour,
        'workEndMinute': workEndMinute,
        'biometricEnabled': biometricEnabled,
        'updatedAt': updatedAt ?? DateTime.now(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, companyName];
}
