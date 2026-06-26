import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/leave_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/leave_balance_providers.dart';
import '../../../providers/service_providers.dart';

/// Self-service home for an employee: their profile, leave balance, leave
/// history and a shortcut to apply for leave. Only shows data the signed-in
/// user is allowed to see (their own).
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'My Space',
            subtitle: 'Your leave balance, requests and profile.',
          ),
          const SizedBox(height: 20),
          _ProfileCard(
            name: user.displayName ?? user.email,
            email: user.email,
            role: RolePermissions.effectiveRole(user.role).replaceAll('_', ' '),
            department: user.departmentName,
          ),
          const SizedBox(height: 16),
          if (empId == null || empId.isEmpty)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 6),
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded, color: AppColors.textFaint),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your account isn\'t linked to an employee profile yet. '
                        'Ask your admin to link it so you can see your leave '
                        'balance and apply for leave.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _downloadReport(context, ref, user),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download My Report (PDF)'),
              ),
            ),
            const SizedBox(height: 16),
            _LeaveBalanceSection(employeeId: empId),
            const SizedBox(height: 16),
            _SalarySection(employeeId: empId),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My leave requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading,
                        ),
                  ),
                ),
                PrimaryButton(
                  label: 'Apply for leave',
                  icon: Icons.add,
                  onPressed: () => context.go('/leave'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MyLeaveList(employeeId: empId),
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
      final company =
          ref.read(companySettingsProvider).valueOrNull?.companyName ??
              'Company';
      await ref.read(exportServiceProvider).shareMyReportPdf(
            companyName: company,
            employeeName: user.displayName ?? user.email,
            role:
                RolePermissions.effectiveRole(user.role).replaceAll('_', ' '),
            department: user.departmentName,
            email: user.email,
            leaves: leaves,
            payroll: payroll,
          );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not build report: $e')));
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.role,
    required this.department,
  });
  final String name;
  final String email;
  final String role;
  final String? department;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          InitialAvatar(name: name, size: 52),
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
                Text(email,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _pill(role, AppColors.brandNavy),
                    if (department != null && department!.isNotEmpty)
                      _pill(department!, AppColors.brandBlue),
                  ],
                ),
              ],
            ),
          ),
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

class _LeaveBalanceSection extends ConsumerWidget {
  const _LeaveBalanceSection({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(employeeLeaveBalancesProvider(employeeId));
    if (balances.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave balance — ${DateTime.now().year}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.heading,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final b in balances) ...[
              Expanded(child: _BalanceCard(balance: b)),
              if (b != balances.last) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final LeaveBalance balance;

  String _label(LeaveType t) =>
      '${t.name[0].toUpperCase()}${t.name.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final over = balance.overLimit;
    final color = over ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            over ? '0' : '${balance.remaining}',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 22, color: color),
          ),
          Text('of ${balance.allowance} days left',
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(_label(balance.type),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading)),
          Text('${balance.used} used',
              style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
        ],
      ),
    );
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My salary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading,
                  ),
            ),
            const SizedBox(height: 12),
            for (final p in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_monthNames[(p.month - 1).clamp(0, 11)]} ${p.year}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_rs(p.calculatedNet),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          Text(p.status.name,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textFaint)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyLeaveList extends ConsumerWidget {
  const _MyLeaveList({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(employeeLeaveHistoryProvider(employeeId));
    final fmt = DateFormat('dd MMM yyyy');
    return leavesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Could not load your leave: $e',
              style: const TextStyle(color: AppColors.textMuted)),
        ),
      ),
      data: (leaves) {
        if (leaves.isEmpty) {
          return const AppCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('No leave requests yet.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
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
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l.leaveType.name[0].toUpperCase()}${l.leaveType.name.substring(1)}'
                              ' leave • ${l.days} day${l.days == 1 ? "" : "s"}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heading),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${fmt.format(l.startDate)} → ${fmt.format(l.endDate)}'
                              '${(l.reason?.isNotEmpty ?? false) ? "  •  ${l.reason}" : ""}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: l.status),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case LeaveStatus.approved:
        c = AppColors.success;
      case LeaveStatus.rejected:
        c = AppColors.error;
      case LeaveStatus.cancelled:
        c = AppColors.textFaint;
      default:
        c = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${status.name[0].toUpperCase()}${status.name.substring(1)}',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}
