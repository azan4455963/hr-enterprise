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
    this.leaveAllowances = defaultLeaveAllowances,
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

  /// Annual leave entitlement (days) per leave type, keyed by `LeaveType.name`.
  /// A type with 0 (or absent) is treated as untracked / unlimited (e.g. unpaid).
  final Map<String, int> leaveAllowances;
  final DateTime? updatedAt;

  /// Sensible starting policy — the admin can change these in Settings.
  static const Map<String, int> defaultLeaveAllowances = {
    'annual': 14,
    'sick': 8,
    'casual': 10,
  };

  /// Entitled days for a leave type by name (0 = untracked).
  int allowanceForName(String typeName) => leaveAllowances[typeName] ?? 0;

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
      leaveAllowances: _parseAllowances(map['leaveAllowances']),
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
        'leaveAllowances': leaveAllowances,
        'updatedAt': updatedAt ?? DateTime.now(),
      };

  static Map<String, int> _parseAllowances(dynamic value) {
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key.toString(): (e.value as num?)?.toInt() ?? 0,
      };
    }
    return defaultLeaveAllowances;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, companyName, leaveAllowances];
}
