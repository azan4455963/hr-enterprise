import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/attendance_model.dart';
import '../../../models/employee_model.dart';
import '../../../models/leave_model.dart';
import '../../../models/payroll_model.dart';
import '../../../models/google_sheet_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/drive_providers.dart';
import '../../../providers/google_sheets_providers.dart';
import '../../../providers/service_providers.dart';

/// Employee 360° profile — type a name (top-bar search) and land here to see
/// everything about a person from joining to date: profile, attendance, leave
/// and payroll history.
class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(employeeByIdProvider(employeeId));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    return empAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (emp) {
        if (emp == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(child: Text('Employee not found')),
          );
        }
        return DefaultTabController(
          length: 5,
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.heading),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/employees'),
              ),
              title: Text(
                emp.fullName,
                style: const TextStyle(
                    color: AppColors.heading, fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      color: AppColors.brandNavy),
                  tooltip: 'PDF Report',
                  onPressed: () =>
                      context.push('/employees/$employeeId/report'),
                ),
                PermissionGate(
                  permission: 'employees_edit',
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.brandNavy),
                    tooltip: 'Edit',
                    onPressed: () => context.push('/employees/$employeeId/edit'),
                  ),
                ),
                PermissionGate(
                  permission: 'employees_delete',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                labelColor: AppColors.brandNavy,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.brandNavy,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Attendance'),
                  Tab(text: 'Leave'),
                  Tab(text: 'Payroll'),
                  Tab(text: 'Sheet Data'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OverviewTab(emp: emp, canViewSalary: canViewSalary),
                _AttendanceTab(employeeId: employeeId),
                _LeaveTab(employeeId: employeeId),
                _PayrollTab(
                    employeeId: employeeId, canViewSalary: canViewSalary),
                _SheetDataTab(name: emp.fullName, email: emp.email),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        await ref
            .read(employeeServiceProvider)
            .deleteEmployee(employeeId, userId: user.id);
      }
      if (context.mounted) context.go('/employees');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }
}

String _fmtDate(DateTime? d) =>
    d == null ? '—' : DateFormat('dd MMM yyyy').format(d);
String _fmtMoney(double v) => 'Rs ${NumberFormat('#,##0').format(v)}';

/// ── Overview tab ────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.emp, required this.canViewSalary});
  final EmployeeModel emp;
  final bool canViewSalary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final att = ref.watch(employeeAttendanceHistoryProvider(emp.id));
    final leave = ref.watch(employeeLeaveHistoryProvider(emp.id));

    final presentDays = att.valueOrNull
            ?.where((a) =>
                a.status == AttendanceStatus.present ||
                a.status == AttendanceStatus.late)
            .length ??
        0;
    final leavesTaken = leave.valueOrNull
            ?.where((l) => l.status == LeaveStatus.approved)
            .fold<int>(0, (s, l) => s + l.days) ??
        0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        AppCard(
          child: Row(
            children: [
              InitialAvatar(name: emp.fullName, size: 64),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.fullName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.heading)),
                    const SizedBox(height: 2),
                    Text(
                      '${emp.position ?? '—'} · ${emp.departmentName ?? 'No department'}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    _statusPill(emp.status),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick stats
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                label: 'Present Days',
                value: '$presentDays',
                icon: Icons.check_circle_outline,
                color: AppColors.pillGreenFg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                label: 'Leaves Taken',
                value: '$leavesTaken',
                icon: Icons.beach_access_rounded,
                color: AppColors.pillAmberFg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                label: 'Tenure',
                value: _tenure(emp.joiningDate),
                icon: Icons.timelapse_rounded,
                color: AppColors.brandBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _infoCard('Personal Information', [
          _row('Full Name', emp.fullName),
          _row('Father Name', emp.fatherName ?? '—'),
          _row('CNIC', emp.cnic ?? '—'),
          _row('Address', emp.address ?? '—'),
        ]),
        _infoCard('Contact', [
          _row('Email', emp.email),
          _row('Phone', emp.phone ?? '—'),
        ]),
        _infoCard('Employment', [
          _row('Employee ID',
              '#EMP-${emp.id.length >= 6 ? emp.id.substring(0, 6).toUpperCase() : emp.id.toUpperCase()}'),
          _row('Joining Date', _fmtDate(emp.joiningDate)),
          if (emp.leavingDate != null)
            _row('Leaving Date', _fmtDate(emp.leavingDate)),
          _row('Department', emp.departmentName ?? '—'),
          _row('Designation', emp.position ?? '—'),
          if (canViewSalary)
            _row('Salary', emp.salary != null ? _fmtMoney(emp.salary!) : '—'),
        ]),
        if (emp.documentUrls.isNotEmpty)
          _infoCard('Documents', [
            for (final url in emp.documentUrls)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file, size: 20),
                title: Text(url.split('/').last,
                    style: const TextStyle(fontSize: 13)),
                dense: true,
              ),
          ]),
      ],
    );
  }

  static String _tenure(DateTime? joining) {
    if (joining == null) return '—';
    final months = (DateTime.now().difference(joining).inDays / 30).floor();
    if (months < 1) return '<1 mo';
    if (months < 12) return '$months mo';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem == 0 ? '$years yr' : '$years yr $rem mo';
  }
}

Widget _statusPill(EmployeeStatus status) {
  switch (status) {
    case EmployeeStatus.active:
      return StatusPill.green('Active');
    case EmployeeStatus.pending:
      return StatusPill.amber('Pending');
    case EmployeeStatus.inactive:
      return StatusPill.red('Inactive');
    case EmployeeStatus.terminated:
      return StatusPill.red('Left');
  }
}

Widget _infoCard(String title, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.heading)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
        ),
      ],
    ),
  );
}

/// A titled card with a list of rows — used for Salary/Bonuses/Increments/etc.
Widget _sectionCard(String title, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.heading)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

/// A label → value line (value right-aligned, optionally coloured).
Widget _lineRow(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heading)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textBody)),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// ── Attendance tab ──────────────────────────────────────────────────────
class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(employeeAttendanceHistoryProvider(employeeId));
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorOrEmpty(message: 'Could not load attendance.\n$e'),
      data: (rows) {
        if (rows.isEmpty) {
          return const _ErrorOrEmpty(message: 'No attendance records yet.');
        }
        // Group by month (newest first), keeping each month's days.
        final sorted = [...rows]..sort((a, b) => b.date.compareTo(a.date));
        final byMonth = <String, List<AttendanceModel>>{};
        for (final a in sorted) {
          final key = DateFormat('MMM yyyy').format(a.date);
          byMonth.putIfAbsent(key, () => []).add(a);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in byMonth.entries)
              _MonthAttendanceCard(month: entry.key, days: entry.value),
          ],
        );
      },
    );
  }

}

Widget _attendancePillFor(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return StatusPill.green('Present');
    case AttendanceStatus.late:
      return StatusPill.amber('Late');
    case AttendanceStatus.halfDay:
      return StatusPill.amber('Half Day');
    case AttendanceStatus.onLeave:
      return StatusPill.amber('On Leave');
    case AttendanceStatus.absent:
      return StatusPill.red('Absent');
  }
}

/// One month of attendance: header with a summary, then each day.
class _MonthAttendanceCard extends StatelessWidget {
  const _MonthAttendanceCard({required this.month, required this.days});
  final String month;
  final List<AttendanceModel> days;

  @override
  Widget build(BuildContext context) {
    final present = days
        .where((a) =>
            a.status == AttendanceStatus.present ||
            a.status == AttendanceStatus.late)
        .length;
    final absent =
        days.where((a) => a.status == AttendanceStatus.absent).length;
    final onLeave =
        days.where((a) => a.status == AttendanceStatus.onLeave).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(month,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.heading)),
                ),
                Text('P:$present  A:$absent  L:$onLeave',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
              ],
            ),
            const Divider(height: 18, color: AppColors.cardBorder),
            for (final a in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_fmtDate(a.date),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textBody)),
                    ),
                    Text(
                      '${a.checkIn != null ? DateFormat('hh:mm a').format(a.checkIn!) : '—'}'
                      ' → '
                      '${a.checkOut != null ? DateFormat('hh:mm a').format(a.checkOut!) : '—'}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textFaint),
                    ),
                    const SizedBox(width: 10),
                    _attendancePillFor(a.status),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ── Leave tab ───────────────────────────────────────────────────────────
class _LeaveTab extends ConsumerWidget {
  const _LeaveTab({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(employeeLeaveHistoryProvider(employeeId));
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorOrEmpty(message: 'Could not load leave.\n$e'),
      data: (rows) {
        if (rows.isEmpty) {
          return const _ErrorOrEmpty(message: 'No leave requests yet.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final l = rows[i];
            return AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.leaveType.name[0].toUpperCase()}${l.leaveType.name.substring(1)} leave · ${l.days} day(s)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColors.heading),
                        ),
                      ),
                      _leavePill(l.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${_fmtDate(l.startDate)} → ${_fmtDate(l.endDate)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                  if (l.reason?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(l.reason!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textBody)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _leavePill(LeaveStatus s) {
    switch (s) {
      case LeaveStatus.approved:
        return StatusPill.green('Approved');
      case LeaveStatus.pending:
        return StatusPill.amber('Pending');
      case LeaveStatus.rejected:
        return StatusPill.red('Rejected');
      case LeaveStatus.cancelled:
        return StatusPill.red('Cancelled');
    }
  }
}

/// ── Payroll tab ─────────────────────────────────────────────────────────
class _PayrollTab extends ConsumerWidget {
  const _PayrollTab({required this.employeeId, required this.canViewSalary});
  final String employeeId;
  final bool canViewSalary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canViewSalary) {
      return const _ErrorOrEmpty(
          message: 'You do not have permission to view payroll.');
    }
    final history = ref.watch(employeePayrollHistoryProvider(employeeId));
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorOrEmpty(message: 'Could not load payroll.\n$e'),
      data: (rows) {
        if (rows.isEmpty) {
          return const _ErrorOrEmpty(message: 'No payroll records yet.');
        }
        // Oldest → newest, for increments & chronological display.
        final sorted = [...rows]
          ..sort((a, b) => DateTime(a.year, a.month)
              .compareTo(DateTime(b.year, b.month)));

        final incRows = <Widget>[];
        double? prevBase;
        for (final p in sorted) {
          if (prevBase != null && p.baseSalary != prevBase) {
            final up = p.baseSalary > prevBase;
            incRows.add(_lineRow(
              DateFormat('MMM yyyy').format(DateTime(p.year, p.month)),
              '${_fmtMoney(prevBase)} → ${_fmtMoney(p.baseSalary)}',
              valueColor: up ? AppColors.pillGreenFg : AppColors.pillRedFg,
            ));
          }
          prevBase = p.baseSalary;
        }

        final newToOld = sorted.reversed.toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard('Salary — Monthly', [
              for (final p in newToOld)
                _lineRow(
                  DateFormat('MMM yyyy').format(DateTime(p.year, p.month)),
                  'Net ${_fmtMoney(p.calculatedNet)}  ·  Base ${_fmtMoney(p.baseSalary)}',
                ),
            ]),
            _sectionCard('Bonuses', [
              for (final p in newToOld.where((p) => p.bonuses > 0))
                _lineRow(
                  DateFormat('MMM yyyy').format(DateTime(p.year, p.month)),
                  _fmtMoney(p.bonuses),
                  valueColor: AppColors.pillGreenFg,
                ),
              if (newToOld.every((p) => p.bonuses <= 0))
                const Text('No bonuses recorded',
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
            ]),
            _sectionCard('Increments', [
              if (incRows.isEmpty)
                const Text('No salary changes recorded',
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint))
              else
                ...incRows,
            ]),
            _sectionCard('Payments', [
              for (final p in newToOld)
                _lineRow(
                  DateFormat('MMM yyyy').format(DateTime(p.year, p.month)),
                  p.status == PaymentStatus.paid
                      ? 'Paid${p.paidAt != null ? " · ${_fmtDate(p.paidAt)}" : ""}'
                      : p.status.name[0].toUpperCase() +
                          p.status.name.substring(1),
                  valueColor: p.status == PaymentStatus.paid
                      ? AppColors.pillGreenFg
                      : AppColors.pillAmberFg,
                ),
            ]),
          ],
        );
      },
    );
  }
}

/// ── Sheet Data tab (aggregated from all attached Google Sheets) ─────────
class _SheetDataTab extends ConsumerWidget {
  const _SheetDataTab({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (name: name, email: email);
    final sheetRecords = ref.watch(employeeSheetRecordsProvider(key));
    final driveRecords = ref.watch(driveSheetRecordsProvider(key));

    // Combine attached-sheet and Drive matches; show a spinner only while the
    // first source is still loading.
    if (sheetRecords.isLoading && !sheetRecords.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    return _build(
      context,
      <SheetMatch>[
        ...?sheetRecords.valueOrNull,
        ...?driveRecords.valueOrNull,
      ],
      driveLoading: driveRecords.isLoading,
    );
  }

  Widget _build(BuildContext context, List<SheetMatch> matches,
      {required bool driveLoading}) {
    if (matches.isEmpty) {
      return _ErrorOrEmpty(
        message: driveLoading
            ? 'Searching attached sheets and Google Drive…'
            : 'No matching rows found in attached sheets or Drive.\n'
                'Make sure a sheet contains this person\'s name or email.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final m in matches) ...[
          Row(
            children: [
              const Icon(Icons.table_chart_rounded,
                  size: 16, color: AppColors.brandNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(m.sheetTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.heading)),
              ),
              Text('${m.records.length} row(s)',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          for (final record in m.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in record.entries)
                      if (entry.value.isNotEmpty) _row(entry.key, entry.value),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ErrorOrEmpty extends StatelessWidget {
  const _ErrorOrEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ),
    );
  }
}
