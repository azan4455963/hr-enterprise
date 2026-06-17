import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/attendance_qr.dart';
import '../core/utils/app_exception.dart';
import '../models/attendance_model.dart';
import '../models/company_settings_model.dart';
import '../repositories/attendance_repository.dart';
import 'attendance_qr_service.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import 'user_backend_service.dart';

class AttendanceService {
  AttendanceService({
    AttendanceRepository? attendanceRepository,
    UserBackendService? userBackend,
    AttendanceQrService? qrService,
    NotificationService? notificationService,
  })  : _attendance = attendanceRepository ?? AttendanceRepository(),
        _userBackend = userBackend ?? UserBackendService(),
        _qrService = qrService ?? AttendanceQrService(),
        _notifications = notificationService ?? NotificationService();

  final AttendanceRepository _attendance;
  final UserBackendService _userBackend;
  final AttendanceQrService _qrService;
  final NotificationService _notifications;

  /// Delegates to [UserBackendService.canMarkAttendance].
  Future<bool> canMarkAttendance(String uid) =>
      _userBackend.canMarkAttendance(uid);

  Stream<List<AttendanceModel>> watchTodayAttendance({String? departmentId}) =>
      _attendance.watchToday();

  Stream<List<AttendanceModel>> watchRecent({int days = 30}) =>
      _attendance.watchRecent(days: days);

  Stream<List<AttendanceModel>> watchEmployeeHistory(String employeeId) {
    return FirebaseFirestore.instance
        .collection(AppConstants.attendanceCollection)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('date', descending: true)
        .limit(60)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceModel.fromMap(d.id, d.data()))
            .toList());
  }

  AttendanceStatus _resolveStatus(DateTime checkIn, CompanySettingsModel settings) {
    final workStart = DateTime(
      checkIn.year,
      checkIn.month,
      checkIn.day,
      settings.workStartHour,
      settings.workStartMinute,
    );
    final lateThreshold =
        workStart.add(Duration(minutes: settings.lateAfterMinutes));
    if (checkIn.isAfter(lateThreshold)) return AttendanceStatus.late;
    return AttendanceStatus.present;
  }

  Future<void> checkIn({
    required String uid,
    String? employeeName,
    AttendanceMethod method = AttendanceMethod.manual,
    String? deviceId,
    CompanySettingsModel? settings,
  }) async {
    final employeeId = await _userBackend.requireEmployeeIdForAttendance(uid);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final status = settings != null
        ? _resolveStatus(now, settings)
        : AttendanceStatus.present;
    final methodName = method.name;

    final docRef = await _attendance.findTodayRecord(employeeId);
    if (docRef != null) {
      final snap = await docRef.get();
      if (snap.data()?['checkIn'] != null) {
        throw AppException('Already checked in today');
      }
      await _attendance.updateRecord(docRef.id, data: {
        'checkIn': Timestamp.fromDate(now),
        'timestamp': Timestamp.fromDate(now),
        'status': status.name,
        'method': methodName,
        'attendanceMethod': methodName,
        'deviceId': deviceId,
        'employeeName': ?employeeName,
      });
    } else {
      await _attendance.createRecord(
        employeeId: employeeId,
        status: status.name,
        timestamp: now,
        method: methodName,
        employeeName: employeeName,
        date: today,
        checkIn: now,
      );
    }

    await _notifications.send(
      title: 'Check-in recorded',
      body: '${employeeName ?? employeeId} checked in (${status.name})',
      type: NotificationType.attendance,
      userId: uid,
    );
  }

  Future<void> checkOut({
    required String uid,
    String? employeeName,
    AttendanceMethod method = AttendanceMethod.manual,
  }) async {
    final employeeId = await _userBackend.requireEmployeeIdForAttendance(uid);
    final now = DateTime.now();
    final methodName = method.name;

    final docRef = await _attendance.findTodayRecord(employeeId);
    if (docRef == null) throw AppException('No check-in found for today');
    final snap = await docRef.get();
    if (snap.data()?['checkIn'] == null) {
      throw AppException('Check in before checking out');
    }
    if (snap.data()?['checkOut'] != null) {
      throw AppException('Already checked out today');
    }

    await _attendance.updateRecord(docRef.id, data: {
      'checkOut': Timestamp.fromDate(now),
      'timestamp': Timestamp.fromDate(now),
      'method': methodName,
      'attendanceMethod': methodName,
      'employeeName': ?employeeName,
    });

    await _notifications.send(
      title: 'Check-out recorded',
      body: '${employeeName ?? employeeId} checked out',
      type: NotificationType.attendance,
      userId: uid,
    );
  }

  Future<void> processQrScan({
    required String uid,
    required String rawQr,
    String? employeeName,
    CompanySettingsModel? settings,
  }) async {
    final payload = AttendanceQrPayload.decode(rawQr);
    if (payload == null) throw AppException('Invalid QR code');

    final session = await _qrService.validateToken(
      companyId: payload.companyId,
      sessionToken: payload.sessionToken,
    );
    if (session == null) throw AppException('QR session expired or invalid');

    if (payload.action == 'IN') {
      await checkIn(
        uid: uid,
        employeeName: employeeName,
        method: AttendanceMethod.qr,
        deviceId: session.id,
        settings: settings,
      );
    } else {
      await checkOut(
        uid: uid,
        employeeName: employeeName,
        method: AttendanceMethod.qr,
      );
    }
  }

  Future<({int present, int absent, int late, int totalEmployees})> getTodayStats(
    int totalEmployees,
  ) async {
    final records = await watchTodayAttendance().first;
    final checkedIn = records.length;
    return (
      present: records
          .where((r) => r.status == AttendanceStatus.present)
          .length,
      absent: (totalEmployees - checkedIn).clamp(0, totalEmployees),
      late: records.where((r) => r.status == AttendanceStatus.late).length,
      totalEmployees: totalEmployees,
    );
  }

  Future<List<AttendanceModel>> fetchForExport({int days = 30}) async {
    return watchRecent(days: days).first;
  }
}
