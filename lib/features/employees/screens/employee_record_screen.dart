import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/employee_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/leave_balance_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/table_attendance_providers.dart';

/// Employee Record (360): pick a person and see all their data in one place —
/// attendance (pulled live from the custom tables), salary and leave — plus a
/// one-click Excel export. Read-only / computed; nothing is stored.
class EmployeeRecordScreen extends ConsumerStatefulWidget {
  const EmployeeRecordScreen({super.key});

  @override
  ConsumerState<EmployeeRecordScreen> createState() =>
      _EmployeeRecordScreenState();
}

class _EmployeeRecordScreenState extends ConsumerState<EmployeeRecordScreen> {
  String? _selectedId;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final employees = ref.watch(employeesProvider).valueOrNull ?? const [];
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    EmployeeModel? emp;
    for (final e in employees) {
      if (e.id == _selectedId) {
        emp = e;
        break;
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Employee Record',
            subtitle:
                "One place for a person's attendance, salary and leave — pulled "
                'live from across the app.',
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded,
                    color: AppColors.brandNavy),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedId,
                      hint: const Text('Choose an employee…'),
                      items: [
                        for (final e in employees)
                          DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              '${e.fullName}'
                              '${(e.departmentName?.isNotEmpty ?? false) ? "  ·  ${e.departmentName}" : ""}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _selectedId = v),
                    ),
                  ),
                ),
                if (emp != null) ...[
                  const SizedBox(width: 10),
                  _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : PrimaryButton(
                          label: 'Export Excel',
                          icon: Icons.file_download_outlined,
                          onPressed: () => _exportExcel(emp!, canViewSalary),
                        ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (emp == null)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text('Pick an employee to see their full record.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            )
          else
            _Record(employee: emp, canViewSalary: canViewSalary),
        ],
      ),
    );
  }

  Future<void> _exportExcel(EmployeeModel emp, bool canViewSalary) async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final att = ref.read(employeeTableAttendanceProvider(emp.fullName));
      final payroll =
          await ref.read(employeePayrollHistoryProvider(emp.id).future);
      final leaves =
          await ref.read(employeeLeaveHistoryProvider(emp.id).future);
      final bytes = await ref.read(exportServiceProvider).buildEmployeeRecordExcel(
            employee: emp,
            presentDays: att.present,
            lateDays: att.late,
            leaveDays: att.leave,
            absentDays: att.absent,
            attendance: [
              for (final e in att.entries)
                (date: e.dateStr, status: e.status, source: e.source),
            ],
            payroll: payroll,
            leaves: leaves,
            includeSalary: canViewSalary,
          );
      final safe = emp.fullName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '_');
      await saveBytes(
        bytes,
        '${safe}_record.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _Record extends ConsumerWidget {
  const _Record({required this.employee, required this.canViewSalary});
  final EmployeeModel employee;
  final bool canViewSalary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final att = ref.watch(employeeTableAttendanceProvider(employee.fullName));
    final payroll =
        ref.watch(employeePayrollHistoryProvider(employee.id)).valueOrNull ??
            const [];
    final leaves =
        ref.watch(employeeLeaveHistoryProvider(employee.id)).valueOrNull ??
            const [];
    final balances = ref.watch(employeeLeaveBalancesProvider(employee.id));
    final dayFmt = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile header
        AppCard(
          child: Row(
            children: [
              InitialAvatar(name: employee.fullName, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.heading)),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.position ?? "-"}  ·  ${employee.departmentName ?? "-"}'
                      '${canViewSalary && employee.salary != null ? "  ·  Salary ${employee.salary!.toStringAsFixed(0)}" : ""}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Attendance (from tables)
        _sectionTitle(context, 'Attendance (from tables)'),
        const SizedBox(height: 10),
        Row(
          children: [
            _stat('Present', att.present, AppColors.success),
            const SizedBox(width: 10),
            _stat('Late', att.late, AppColors.warning),
            const SizedBox(width: 10),
            _stat('Leave', att.leave, AppColors.brandBlue),
            const SizedBox(width: 10),
            _stat('Absent', att.absent, AppColors.error),
          ],
        ),
        const SizedBox(height: 12),
        if (att.entries.isEmpty)
          _empty(
            "No attendance found in the tables for this person. Make sure a "
            'table column is named like "${employee.fullName}".',
          )
        else
          _tableCard(
            DataTable(
              columnSpacing: 26,
              headingRowHeight: 38,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 40,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Source')),
              ],
              rows: [
                for (final e in att.entries.take(120))
                  DataRow(cells: [
                    DataCell(Text(e.dateStr)),
                    DataCell(Text(e.status)),
                    DataCell(Text(e.source,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted))),
                  ]),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Salary
        if (canViewSalary) ...[
          _sectionTitle(context, 'Salary'),
          const SizedBox(height: 10),
          if (payroll.isEmpty)
            _empty('No salary records yet.')
          else
            _tableCard(
              DataTable(
                columnSpacing: 22,
                headingRowHeight: 38,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Base')),
                  DataColumn(label: Text('Bonus')),
                  DataColumn(label: Text('Deduct')),
                  DataColumn(label: Text('Net')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final p in payroll)
                    DataRow(cells: [
                      DataCell(Text('${p.month}/${p.year}')),
                      DataCell(Text(p.baseSalary.toStringAsFixed(0))),
                      DataCell(Text(p.bonuses.toStringAsFixed(0))),
                      DataCell(Text(p.deductions.toStringAsFixed(0))),
                      DataCell(Text(p.calculatedNet.toStringAsFixed(0),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary))),
                      DataCell(Text(p.status.name)),
                    ]),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],

        // Leave
        _sectionTitle(context, 'Leave'),
        const SizedBox(height: 10),
        if (balances.isNotEmpty) ...[
          Row(
            children: [
              for (final b in balances) ...[
                _stat(
                  '${b.type.name[0].toUpperCase()}${b.type.name.substring(1)} left',
                  b.overLimit ? 0 : b.remaining,
                  b.overLimit ? AppColors.error : AppColors.success,
                ),
                if (b != balances.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (leaves.isEmpty)
          _empty('No leave requests.')
        else
          _tableCard(
            DataTable(
              columnSpacing: 22,
              headingRowHeight: 38,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 40,
              columns: const [
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('From')),
                DataColumn(label: Text('To')),
                DataColumn(label: Text('Days')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final l in leaves)
                  DataRow(cells: [
                    DataCell(Text(l.leaveType.name)),
                    DataCell(Text(dayFmt.format(l.startDate))),
                    DataCell(Text(dayFmt.format(l.endDate))),
                    DataCell(Text('${l.days}')),
                    DataCell(Text(l.status.name)),
                  ]),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.heading,
            ),
      );

  Widget _stat(String label, int value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: color)),
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      );

  Widget _tableCard(Widget table) => AppCard(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      );

  Widget _empty(String text) => AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
          child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
}
