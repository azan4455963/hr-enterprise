import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_request_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_qr_session_model.dart';
import '../models/audit_log_model.dart';
import '../models/company_settings_model.dart';
import '../models/department_model.dart';
import '../models/employee_document_model.dart';
import '../models/employee_model.dart';
import '../models/employee_record_model.dart';
import '../models/leave_model.dart';
import '../models/notification_model.dart';
import '../models/onboarding_model.dart';
import '../models/payroll_model.dart';
import '../models/user_model.dart';
import '../core/constants/permissions.dart';
import 'auth_provider.dart';
import 'service_providers.dart';

final companySettingsProvider = StreamProvider<CompanySettingsModel>((ref) {
  return ref.watch(companySettingsServiceProvider).watchSettings();
});

final departmentsProvider = StreamProvider<List<DepartmentModel>>((ref) {
  return ref.watch(departmentServiceProvider).watchDepartments();
});

/// All users (for admin to pick directors).
final usersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).watchAll();
});

/// Pending feature-access requests (admin view).
final pendingAccessRequestsProvider =
    StreamProvider<List<AccessRequestModel>>((ref) {
  return ref.watch(accessRequestServiceProvider).watchPending();
});

/// One user's own feature-access requests (any status).
final myAccessRequestsProvider =
    StreamProvider.family<List<AccessRequestModel>, String>((ref, userId) {
  return ref.watch(accessRequestServiceProvider).watchForUser(userId);
});

final employeesProvider = StreamProvider<List<EmployeeModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final service = ref.watch(employeeServiceProvider);

  // Director (manager): scoped to their managed department(s).
  if (user != null &&
      user.role == RolePermissions.manager &&
      user.departments.isNotEmpty) {
    return service.watchEmployees(departmentNames: user.departments);
  }

  // Admin / others: everyone.
  return service.watchEmployees();
});

/// Employee ids in the current user's scope, or null when there is no scoping
/// (admin sees everything). A director is scoped to their department; a plain
/// employee is scoped to only their own linked record so they never see other
/// people's leave/attendance.
final _scopedEmployeeIdsProvider = Provider<Set<String>?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;
  if (RolePermissions.isSuperAdmin(user.role)) return null; // sees everything
  if (user.role == RolePermissions.manager) {
    final emps = ref.watch(employeesProvider).valueOrNull ?? const [];
    return emps.map((e) => e.id).toSet();
  }
  // Plain employee → only their own linked employee id.
  final eid = user.employeeId;
  return (eid == null || eid.isEmpty) ? <String>{} : {eid};
});

final todayAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final ids = ref.watch(_scopedEmployeeIdsProvider);
  return ref.watch(attendanceServiceProvider).watchTodayAttendance().map(
        (list) => ids == null
            ? list
            : list.where((a) => ids.contains(a.employeeId)).toList(),
      );
});

/// Look up a single employee by id (whole profile).
final employeeByIdProvider =
    FutureProvider.family<EmployeeModel?, String>((ref, id) {
  return ref.watch(employeeServiceProvider).getEmployee(id);
});

/// Full attendance history for one employee (most recent first).
final employeeAttendanceHistoryProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, employeeId) {
  return ref.watch(attendanceServiceProvider).watchEmployeeHistory(employeeId);
});

/// Full leave history for one employee.
final employeeLeaveHistoryProvider =
    StreamProvider.family<List<LeaveRequestModel>, String>((ref, employeeId) {
  return ref.watch(leaveServiceProvider).watchByEmployee(employeeId);
});

/// Full payroll history for one employee (filtered client-side).
final employeePayrollHistoryProvider =
    StreamProvider.family<List<PayrollModel>, String>((ref, employeeId) {
  return ref.watch(payrollServiceProvider).watchPayroll().map(
        (list) => list.where((p) => p.employeeId == employeeId).toList(),
      );
});

/// One employee's payroll via a constrained query — used by employee
/// self-service so it works under the per-employee payroll read rule.
final myPayrollProvider =
    StreamProvider.family<List<PayrollModel>, String>((ref, employeeId) {
  return ref.watch(payrollServiceProvider).watchForEmployee(employeeId);
});

/// Free-form custom records stored under one employee's id.
final employeeRecordsProvider =
    StreamProvider.family<List<EmployeeRecordModel>, String>((ref, employeeId) {
  return ref.watch(employeeRecordServiceProvider).watch(employeeId);
});

/// One employee's published attendance snapshot (readable by the employee on
/// My Space, since it's marked visibleToEmployee). Null until an admin
/// publishes it.
final myAttendanceSummaryProvider =
    StreamProvider.family<EmployeeRecordModel?, String>((ref, employeeId) {
  return ref
      .watch(employeeRecordServiceProvider)
      .watchAttendanceSummary(employeeId);
});

/// Files (CNIC, contract, certificates…) attached to one employee.
final employeeDocumentsProvider =
    StreamProvider.family<List<EmployeeDocumentModel>, String>((ref, employeeId) {
  return ref.watch(employeeDocumentServiceProvider).watch(employeeId);
});

final recentAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final ids = ref.watch(_scopedEmployeeIdsProvider);
  return ref.watch(attendanceServiceProvider).watchRecent(days: 30).map(
        (list) => ids == null
            ? list
            : list.where((a) => ids.contains(a.employeeId)).toList(),
      );
});

final attendanceStatsProvider =
    FutureProvider<({int present, int absent, int late, int total})>((ref) async {
  final count = await ref.watch(employeeCountProvider.future);
  final stats = await ref.watch(attendanceServiceProvider).getTodayStats(count);
  return (
    present: stats.present,
    absent: stats.absent,
    late: stats.late,
    total: stats.totalEmployees,
  );
});

final activeQrSessionProvider = StreamProvider<AttendanceQrSessionModel?>((ref) {
  return ref.watch(attendanceQrServiceProvider).watchActiveSession();
});

final leaveRequestsProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final ids = ref.watch(_scopedEmployeeIdsProvider);
  return ref.watch(leaveServiceProvider).watchAll().map(
        (list) => ids == null
            ? list
            : list.where((l) => ids.contains(l.employeeId)).toList(),
      );
});

final pendingLeaveProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final ids = ref.watch(_scopedEmployeeIdsProvider);
  return ref.watch(leaveServiceProvider).watchPending().map(
        (list) => ids == null
            ? list
            : list.where((l) => ids.contains(l.employeeId)).toList(),
      );
});

final payrollProvider = StreamProvider<List<PayrollModel>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(payrollServiceProvider)
      .watchPayroll(month: now.month, year: now.year);
});

final onboardingLinksProvider =
    StreamProvider<List<OnboardingLinkModel>>((ref) {
  return ref.watch(onboardingServiceProvider).watchLinks();
});

final onboardingSubmissionsProvider =
    StreamProvider<List<OnboardingSubmissionModel>>((ref) {
  return ref.watch(onboardingServiceProvider).watchSubmissions();
});

final notificationsProvider =
    StreamProvider<List<AppNotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(notificationServiceProvider).watchForUser(user);
});

final employeeCountProvider = FutureProvider<int>((ref) async {
  final employees = await ref.watch(employeesProvider.future);
  return employees
      .where((e) => e.status == EmployeeStatus.active)
      .length;
});

final weeklyAttendanceChartProvider =
    FutureProvider<List<({String day, int count})>>((ref) async {
  final records = await ref.watch(recentAttendanceProvider.future);
  final now = DateTime.now();
  final result = <({String day, int count})>[];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  for (var i = 6; i >= 0; i--) {
    final d = DateTime(now.year, now.month, now.day - i);
    final count = records.where((r) {
      return r.date.year == d.year &&
          r.date.month == d.month &&
          r.date.day == d.day;
    }).length;
    result.add((day: days[d.weekday - 1], count: count));
  }
  return result;
});

final auditLogsProvider = StreamProvider<List<AuditLogModel>>((ref) {
  return ref.watch(auditServiceProvider).watchLogs(limit: 25);
});

/// Full activity feed for the admin Activity Log screen.
final allAuditLogsProvider = StreamProvider<List<AuditLogModel>>((ref) {
  return ref.watch(auditServiceProvider).watchLogs(limit: 300);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).when(
        data: (list) => list.where((n) => !n.isRead).length,
        loading: () => 0,
        error: (_, _) => 0,
      );
});

final onboardingPendingCountProvider = Provider<int>((ref) {
  return ref.watch(onboardingSubmissionsProvider).when(
        data: (list) =>
            list.where((s) => s.status == OnboardingSubmissionStatus.submitted).length,
        loading: () => 0,
        error: (_, _) => 0,
      );
});

typedef DepartmentBreakdownRow = ({
  String name,
  int total,
  int present,
  double pct,
  Color color,
});

final departmentBreakdownProvider =
    FutureProvider<List<DepartmentBreakdownRow>>((ref) async {
  final employees = await ref.watch(employeesProvider.future);
  final today = await ref.watch(todayAttendanceProvider.future);
  final presentIds = today
      .where(
        (a) =>
            a.status == AttendanceStatus.present ||
            a.status == AttendanceStatus.late ||
            a.status == AttendanceStatus.halfDay,
      )
      .map((a) => a.employeeId)
      .toSet();

  const palette = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF22D3EE),
  ];

  final byDept = <String, List<EmployeeModel>>{};
  for (final e in employees.where((e) => e.status == EmployeeStatus.active)) {
    final dept =
        (e.departmentName?.trim().isNotEmpty ?? false) ? e.departmentName! : 'Unassigned';
    byDept.putIfAbsent(dept, () => []).add(e);
  }

  final rows = <DepartmentBreakdownRow>[];
  var colorIndex = 0;
  for (final entry in byDept.entries) {
    final total = entry.value.length;
    final present = entry.value.where((e) => presentIds.contains(e.id)).length;
    final pct = total == 0 ? 0.0 : (present / total) * 100;
    rows.add((
      name: entry.key,
      total: total,
      present: present,
      pct: pct,
      color: palette[colorIndex % palette.length],
    ));
    colorIndex++;
  }
  rows.sort((a, b) => b.pct.compareTo(a.pct));
  return rows.take(6).toList();
});

typedef TopPerformerRow = ({EmployeeModel employee, int score});

final topPerformersProvider = FutureProvider<List<TopPerformerRow>>((ref) async {
  final employees = await ref.watch(employeesProvider.future);
  final records = await ref.watch(recentAttendanceProvider.future);
  final active = employees.where((e) => e.status == EmployeeStatus.active).toList();
  if (active.isEmpty) return [];

  final scored = active.map((emp) {
    final presents = records
        .where(
          (r) =>
              r.employeeId == emp.id &&
              (r.status == AttendanceStatus.present ||
                  r.status == AttendanceStatus.late),
        )
        .length;
    final score = ((presents / 30) * 100).clamp(0, 100).round();
    return (employee: emp, score: score);
  }).toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  return scored.take(4).toList();
});

typedef DashboardActivityItem = ({
  String text,
  DateTime? at,
  Color dotColor,
});

final dashboardActivityProvider =
    FutureProvider<List<DashboardActivityItem>>((ref) async {
  final logs = await ref.watch(auditLogsProvider.future);
  final notifications = await ref.watch(notificationsProvider.future);

  final items = <DashboardActivityItem>[];

  for (final log in logs.take(12)) {
    items.add((
      text: _formatAuditMessage(log),
      at: log.createdAt,
      dotColor: _auditColor(log.module),
    ));
  }

  for (final n in notifications.take(8)) {
    items.add((
      text: n.title.isNotEmpty ? n.title : n.body,
      at: n.createdAt,
      dotColor: _notificationColor(n.type),
    ));
  }

  items.sort((a, b) {
    final ta = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });

  return items.take(8).toList();
});

String _formatAuditMessage(AuditLogModel log) {
  final method = log.details?['method'] as String?;
  switch (log.action) {
    case 'login':
      return method == 'google' ? 'User signed in with Google' : 'User signed in';
    case 'logout':
      return 'User signed out';
    case 'create':
      return 'New ${log.module} record created';
    case 'update':
      return '${log.module} record updated';
    case 'delete':
      return '${log.module} record removed';
    case 'approve':
      return '${log.module} request approved';
    case 'reject':
      return '${log.module} request rejected';
    default:
      return '${log.action} — ${log.module}';
  }
}

Color _auditColor(String module) {
  switch (module) {
    case 'attendance':
      return const Color(0xFF10B981);
    case 'leave':
      return const Color(0xFF6366F1);
    case 'payroll':
      return const Color(0xFFF59E0B);
    case 'auth':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFFEF4444);
  }
}

Color _notificationColor(NotificationType type) {
  switch (type) {
    case NotificationType.attendance:
      return const Color(0xFF10B981);
    case NotificationType.leave:
      return const Color(0xFF6366F1);
    case NotificationType.payroll:
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF94A3B8);
  }
}
