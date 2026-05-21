import 'package:equatable/equatable.dart';

enum LeaveStatus { pending, approved, rejected, cancelled }

enum LeaveType { annual, sick, casual, unpaid, other }

class LeaveRequestModel extends Equatable {
  const LeaveRequestModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.reason,
    this.status = LeaveStatus.pending,
    this.approvedBy,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveType leaveType;
  final String? reason;
  final LeaveStatus status;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get days => endDate.difference(startDate).inDays + 1;

  factory LeaveRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return LeaveRequestModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      startDate: _parseDate(map['startDate']) ?? DateTime.now(),
      endDate: _parseDate(map['endDate']) ?? DateTime.now(),
      leaveType: LeaveType.values.firstWhere(
        (e) => e.name == (map['leaveType'] as String? ?? 'annual'),
        orElse: () => LeaveType.annual,
      ),
      reason: map['reason'] as String?,
      status: LeaveStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'pending'),
        orElse: () => LeaveStatus.pending,
      ),
      approvedBy: map['approvedBy'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'startDate': startDate,
        'endDate': endDate,
        'leaveType': leaveType.name,
        'reason': reason,
        'status': status.name,
        'approvedBy': approvedBy,
        'rejectionReason': rejectionReason,
        'createdAt': createdAt ?? DateTime.now(),
        'updatedAt': updatedAt ?? DateTime.now(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, employeeId, status, startDate];
}
