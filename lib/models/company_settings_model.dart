import 'package:equatable/equatable.dart';

/// A named work shift with a start/end time. Multiple shifts can cover 24h.
class WorkShift extends Equatable {
  const WorkShift({
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  /// Start time as minutes-since-midnight (used to derive the day cutover).
  int get startMinutes => startHour * 60 + startMinute;

  factory WorkShift.fromMap(Map<String, dynamic> m) => WorkShift(
        name: m['name'] as String? ?? 'Shift',
        startHour: (m['startHour'] as num?)?.toInt() ?? 9,
        startMinute: (m['startMinute'] as num?)?.toInt() ?? 0,
        endHour: (m['endHour'] as num?)?.toInt() ?? 17,
        endMinute: (m['endMinute'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
      };

  @override
  List<Object?> get props =>
      [name, startHour, startMinute, endHour, endMinute];
}

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
    this.attendanceDayStartHour = 0,
    this.shifts = const [],
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

  /// Hour (0–23) at which the attendance "day" rolls over. 0 = midnight
  /// (normal). Used only when no [shifts] are defined.
  final int attendanceDayStartHour;

  /// Defined work shifts (name + time). When present, the attendance day rolls
  /// over at the earliest shift's start, so night shifts crossing midnight
  /// stay within one business day.
  final List<WorkShift> shifts;
  final DateTime? updatedAt;

  /// Minutes-since-midnight at which the attendance day rolls over: the earliest
  /// shift start if shifts are defined, else the manual hour.
  int get dayCutoverMinutes {
    if (shifts.isEmpty) return attendanceDayStartHour * 60;
    var min = shifts.first.startMinutes;
    for (final s in shifts) {
      if (s.startMinutes < min) min = s.startMinutes;
    }
    return min;
  }

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
      attendanceDayStartHour:
          (map['attendanceDayStartHour'] as num?)?.toInt() ?? 0,
      shifts: (map['shifts'] as List? ?? const [])
          .map((s) => WorkShift.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
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
        'attendanceDayStartHour': attendanceDayStartHour,
        'shifts': [for (final s in shifts) s.toMap()],
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
  List<Object?> get props =>
      [id, companyName, leaveAllowances, attendanceDayStartHour, shifts];
}
