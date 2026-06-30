import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/employee_model.dart';
import '../../../models/employee_record_model.dart';
import '../../../models/leave_model.dart';
import '../../../models/payroll_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/leave_balance_providers.dart';
import '../../../providers/service_providers.dart';

/// Self-service home for an employee: their profile, leave balance, attendance,
/// salary and leave history. Only ever shows data the signed-in user is allowed
/// to see (their own).
class MySpaceScreen extends ConsumerWidget {
  const MySpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final empId = user.employeeId;
    final linked = empId != null && empId.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'My Space',
            subtitle: 'Your profile, leave balance, attendance and salary.',
          ),
          const SizedBox(height: 20),
          _ProfileHeader(
            user: user,
            onDownload: linked ? () => _downloadReport(context, ref, user) : null,
          ),
          const SizedBox(height: 20),
          if (!linked)
            const _NotLinkedCard()
          else ...[
            _LeaveBalanceSection(employeeId: empId),
            _MyAttendanceSection(employeeId: empId),
            _SalarySection(employeeId: empId),
            _MyLeaveSection(employeeId: empId),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadReport(
      BuildContext context, WidgetRef ref, UserModel user) async {
    final empId = user.employeeId;
    if (empId == null || empId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final leaves =
          await ref.read(employeeLeaveHistoryProvider(empId).future);
      final payroll = await ref.read(myPayrollProvider(empId).future);
      final att = _parseAttendanceRecord(
          await ref.read(myAttendanceSummaryProvider(empId).future));
      final company =
          ref.read(companySettingsProvider).valueOrNull?.companyName ??
              'Company';
      await ref.read(exportServiceProvider).shareMyReportPdf(
            companyName: company,
            employeeName: user.displayName ?? user.email,
            role: RolePermissions.roleLabel(user.role),
            department: user.departmentName,
            email: user.email,
            leaves: leaves,
            payroll: payroll,
            attPresent: att?.present ?? 0,
            attLate: att?.late ?? 0,
            attLeave: att?.leave ?? 0,
            attAbsent: att?.absent ?? 0,
            attendance: att?.dates ?? const [],
          );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not build report: $e')));
    }
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

String _leaveTypeLabel(LeaveType t) =>
    t.name.isEmpty ? t.name : '${t.name[0].toUpperCase()}${t.name.substring(1)}';

IconData _leaveTypeIcon(LeaveType t) {
  switch (t.name) {
    case 'annual':
      return Icons.beach_access_rounded;
    case 'sick':
      return Icons.medical_services_outlined;
    case 'casual':
      return Icons.weekend_outlined;
    case 'unpaid':
      return Icons.money_off_rounded;
    default:
      return Icons.event_note_outlined;
  }
}

StatusPill _leaveStatusPill(LeaveStatus s) {
  switch (s) {
    case LeaveStatus.approved:
      return StatusPill.green('Approved');
    case LeaveStatus.rejected:
      return StatusPill.red('Rejected');
    case LeaveStatus.cancelled:
      return StatusPill.red('Cancelled');
    case LeaveStatus.pending:
      return StatusPill.amber('Pending');
  }
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _rs(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'Rs ${buf.toString()}';
}

/// A small section heading used between My Space cards.
Widget _sectionTitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.heading)),
    );

// ── Profile header ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, this.onDownload});
  final UserModel user;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName ?? user.email;
    final photo = user.photoUrl;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              (photo != null && photo.isNotEmpty)
                  ? CircleAvatar(radius: 28, backgroundImage: NetworkImage(photo))
                  : InitialAvatar(name: name, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.heading)),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _pill(RolePermissions.roleLabel(user.role),
                            AppColors.brandNavy),
                        if ((user.departmentName ?? '').isNotEmpty)
                          _pill(user.departmentName!, AppColors.brandBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onDownload != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download My Record (PDF)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandNavy,
                  side: const BorderSide(color: AppColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      );
}

class _NotLinkedCard extends StatelessWidget {
  const _NotLinkedCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        children: [
          Icon(Icons.link_off_rounded, color: AppColors.textFaint),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your account isn't linked to an employee profile yet. Ask your "
              'admin to link it so you can see your leave balance, attendance '
              'and salary, and apply for leave.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leave balance ───────────────────────────────────────────────────────────

class _LeaveBalanceSection extends ConsumerWidget {
  const _LeaveBalanceSection({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(employeeLeaveBalancesProvider(employeeId));
    if (balances.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Leave Balance · ${DateTime.now().year}'),
          Row(
            children: [
              for (var i = 0; i < balances.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _TypeBalanceCard(balance: balances[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBalanceCard extends StatelessWidget {
  const _TypeBalanceCard({required this.balance});
  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final over = balance.overLimit;
    final color = over ? AppColors.error : AppColors.pillGreenFg;
    final remaining = over ? 0 : balance.remaining;
    final progress =
        balance.allowance > 0 ? remaining / balance.allowance : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_leaveTypeIcon(balance.type),
                    size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_leaveTypeLabel(balance.type),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$remaining',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('/ ${balance.allowance}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text('${balance.used} used',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textFaint)),
        ],
      ),
    );
  }
}

// ── Attendance ──────────────────────────────────────────────────────────────

typedef _AttParsed = ({
  int present,
  int late,
  int leave,
  int absent,
  List<({String date, String status})> dates
});

_AttParsed? _parseAttendanceRecord(EmployeeRecordModel? rec) {
  if (rec == null) return null;
  int val(String label) {
    for (final f in rec.fields) {
      if (f.label.toLowerCase() == label.toLowerCase()) {
        return int.tryParse(f.value) ?? 0;
      }
    }
    return 0;
  }

  final dates = <({String date, String status})>[];
  for (final line in (rec.note ?? '').split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final idx = t.indexOf(': ');
    if (idx > 0) {
      dates.add((date: t.substring(0, idx), status: t.substring(idx + 2)));
    } else {
      dates.add((date: t, status: ''));
    }
  }
  return (
    present: val('Present'),
    late: val('Late'),
    leave: val('Leave'),
    absent: val('Absent'),
    dates: dates,
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 20, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _MyAttendanceSection extends ConsumerWidget {
  const _MyAttendanceSection({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAttendanceSummaryProvider(employeeId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (rec) {
        final p = _parseAttendanceRecord(rec);
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, 'My Attendance'),
              if (p == null)
                const AppCard(
                  child: Text(
                    "Your attendance hasn't been published yet — ask your "
                    'admin to publish it.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                        child: _MiniStat(
                            value: p.present,
                            label: 'Present',
                            icon: Icons.check_circle_outline,
                            color: AppColors.success)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _MiniStat(
                            value: p.late,
                            label: 'Late',
                            icon: Icons.alarm,
                            color: AppColors.warning)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _MiniStat(
                            value: p.leave,
                            label: 'Leave',
                            icon: Icons.beach_access_rounded,
                            color: AppColors.brandBlue)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _MiniStat(
                            value: p.absent,
                            label: 'Absent',
                            icon: Icons.cancel_outlined,
                            color: AppColors.error)),
                  ],
                ),
                if (p.dates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Column(
                      children: [
                        for (final d in p.dates.take(60))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(d.date,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textBody)),
                                ),
                                Text(d.status,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        if (p.dates.length > 60)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('+ ${p.dates.length - 60} more',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textFaint)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Salary ──────────────────────────────────────────────────────────────────

class _SalarySection extends ConsumerWidget {
  const _SalarySection({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payrollAsync = ref.watch(myPayrollProvider(employeeId));
    return payrollAsync.when(
      // Payroll may be restricted until the rules update is deployed — fail
      // quietly rather than showing an error to the employee.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final user = ref.read(currentUserProvider).valueOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, 'My Salary'),
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_monthNames[(p.month - 1).clamp(0, 11)]} ${p.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppColors.heading),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Base ${_rs(p.baseSalary)}'
                                '${p.bonuses > 0 ? " • Bonus ${_rs(p.bonuses)}" : ""}'
                                '${p.deductions > 0 ? " • Ded ${_rs(p.deductions)}" : ""}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_rs(p.calculatedNet),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.primary)),
                            Text(p.status.name,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textFaint)),
                          ],
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Download payslip PDF',
                          icon: const Icon(Icons.receipt_long_outlined,
                              size: 20, color: AppColors.brandNavy),
                          onPressed: user == null
                              ? null
                              : () => _downloadPayslip(context, ref, user, p),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadPayslip(BuildContext context, WidgetRef ref,
      UserModel user, PayrollModel p) async {
    final empId = user.employeeId;
    if (empId == null || empId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final whole = (user.displayName ?? user.email).trim();
    final parts = whole.split(RegExp(r'\s+'));
    final emp = EmployeeModel(
      id: empId,
      firstName: parts.isNotEmpty ? parts.first : whole,
      lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
      email: user.email,
      departmentName: user.departmentName,
    );
    final company =
        ref.read(companySettingsProvider).valueOrNull?.companyName ?? 'Company';
    try {
      await ref.read(exportServiceProvider).sharePayslipPdf(
            employee: emp,
            payroll: p,
            companyName: company,
          );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)));
    }
  }
}

// ── Leave requests ──────────────────────────────────────────────────────────

class _MyLeaveSection extends ConsumerWidget {
  const _MyLeaveSection({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(employeeLeaveHistoryProvider(employeeId));
    final fmt = DateFormat('dd MMM yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'My Leave Requests')),
            PrimaryButton(
              label: 'Apply for leave',
              icon: Icons.add,
              onPressed: () => context.go('/leave'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        leavesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppCard(
            child: Text('Could not load your leave: $e',
                style: const TextStyle(color: AppColors.textMuted)),
          ),
          data: (leaves) {
            if (leaves.isEmpty) {
              return const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 10),
                    Icon(Icons.event_busy_outlined,
                        size: 36, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text('No leave requests yet.',
                        style: TextStyle(color: AppColors.textMuted)),
                    SizedBox(height: 10),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final l in leaves)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.brandBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(_leaveTypeIcon(l.leaveType),
                                size: 19, color: AppColors.brandBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_leaveTypeLabel(l.leaveType)} leave • '
                                  '${l.days} day${l.days == 1 ? "" : "s"}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.heading),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${fmt.format(l.startDate)} → ${fmt.format(l.endDate)}'
                                  '${(l.reason?.isNotEmpty ?? false) ? "  •  ${l.reason}" : ""}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _leaveStatusPill(l.status),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
