import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/utils/firestore_parse.dart';

enum AttendanceStatus { present, absent, late, halfDay, onLeave }

enum AttendanceMethod { manual, qr, fingerprint, face, gps }

class AttendanceModel extends Equatable {
  const AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.date,
    this.employeeName,
    this.departmentName,
    this.checkIn,
    this.checkOut,
    this.status = AttendanceStatus.present,
    this.attendanceMethod = AttendanceMethod.manual,
    this.deviceId,
    this.notes,
    this.createdAt,
    this.timestamp,
  });

  final String id;
  final String employeeId;
  final String? employeeName;
  final String? departmentName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final AttendanceStatus status;
  final AttendanceMethod attendanceMethod;
  /// Primary event time (check-in / mark time).
  final DateTime? timestamp;
  final String? deviceId;
  final String? notes;
  final DateTime? createdAt;

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String?,
      departmentName: map['departmentName'] as String?,
      date: parseFirestoreDate(map['date']) ?? DateTime.now(),
      checkIn: parseFirestoreDate(map['checkIn']),
      checkOut: parseFirestoreDate(map['checkOut']),
      timestamp: parseFirestoreDate(map['timestamp']) ??
          parseFirestoreDate(map['checkIn']),
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'present'),
        orElse: () => AttendanceStatus.present,
      ),
      attendanceMethod: _parseMethod(map),
      deviceId: map['deviceId'] as String?,
      notes: map['notes'] as String?,
      createdAt: parseFirestoreDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final ts = timestamp ?? checkIn ?? DateTime.now();
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'departmentName': departmentName,
      'date': Timestamp.fromDate(date),
      'timestamp': Timestamp.fromDate(ts),
      'checkIn': checkIn != null ? Timestamp.fromDate(checkIn!) : null,
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut!) : null,
      'status': status.name,
      'method': attendanceMethod.name,
      'attendanceMethod': attendanceMethod.name,
      'deviceId': deviceId,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  static AttendanceMethod _parseMethod(Map<String, dynamic> map) {
    final raw = map['method'] as String? ?? map['attendanceMethod'] as String? ?? 'manual';
    return AttendanceMethod.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AttendanceMethod.manual,
    );
  }

  @override
  List<Object?> get props => [id, employeeId, date, status];
}
