import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/employee_model.dart';
import '../../../models/payroll_model.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

/// The month being viewed on the Payroll screen.
final _payrollMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
});

/// Payroll records for the selected month.
final _payrollListProvider =
    StreamProvider.autoDispose<List<PayrollModel>>((ref) {
  final m = ref.watch(_payrollMonthProvider);
  return ref
      .watch(payrollServiceProvider)
      .watchPayroll(month: m.month, year: m.year);
});

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _fmtMoney(double v) {
  final s = v.toStringAsFixed(0);
  // Thousands separators.
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'Rs ${buf.toString()}';
}

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_payrollMonthProvider);
    final payroll = ref.watch(_payrollListProvider);

    return PermissionGate(
      permission: 'payroll_view',
      fallback: const Scaffold(
        body: Center(child: Text('You do not have permission to view payroll')),
      ),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Payroll',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  PermissionGate(
                    permission: 'payroll_edit',
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _generateMonth(context, ref),
                          icon: const Icon(Icons.bolt_outlined, size: 18),
                          label: const Text('Generate month'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showPayrollDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Record'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MonthBar(
                month: month,
                onPrev: () => ref.read(_payrollMonthProvider.notifier).state =
                    DateTime(month.year, month.month - 1),
                onNext: () => ref.read(_payrollMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1),
              ),
              const SizedBox(height: 12),
              payroll.maybeWhen(
                data: (list) => _SummaryBar(records: list),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AsyncValueWidget(
                  value: payroll,
                  onRetry: () => ref.invalidate(_payrollListProvider),
                  data: (list) => list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No payroll records for this month'),
                              const SizedBox(height: 8),
                              PermissionGate(
                                permission: 'payroll_edit',
                                child: TextButton.icon(
                                  onPressed: () => _generateMonth(context, ref),
                                  icon: const Icon(Icons.bolt_outlined),
                                  label: Text(
                                      'Generate for ${_months[month.month - 1]}'),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) =>
                              _PayrollTile(record: list[i]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Generate a whole month from employee profiles ────────────────────────
  Future<void> _generateMonth(BuildContext context, WidgetRef ref) async {
    final month = ref.read(_payrollMonthProvider);
    final messenger = ScaffoldMessenger.of(context);
    final employees = (await ref.read(employeesProvider.future))
        .where((e) =>
            e.status == EmployeeStatus.active && (e.salary ?? 0) > 0)
        .toList();
    final existing = ref.read(_payrollListProvider).valueOrNull ?? const [];
    final existingIds = existing.map((p) => p.employeeId).toSet();
    final toCreate = [
      for (final e in employees)
        if (!existingIds.contains(e.id))
          PayrollModel(
            id: '',
            employeeId: e.id,
            employeeName: e.fullName,
            month: month.month,
            year: month.year,
            baseSalary: e.salary!,
          ),
    ];

    final label = '${_months[month.month - 1]} ${month.year}';
    if (toCreate.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(employees.isEmpty
            ? 'No active employees with a salary set.'
            : 'Every active employee already has a record for $label.'),
      ));
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate payroll'),
        content: Text(
          'Create ${toCreate.length} pending payroll record(s) for $label?\n\n'
          'Base salary is taken from each employee profile. '
          '${existing.isNotEmpty ? "${existing.length} existing record(s) will be kept as-is." : ""}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n =
          await ref.read(payrollServiceProvider).createMany(toCreate);
      messenger.showSnackBar(
          SnackBar(content: Text('Generated $n payroll record(s) for $label.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)));
    }
  }
}

// ── Month navigator ─────────────────────────────────────────────────────────
class _MonthBar extends StatelessWidget {
  const _MonthBar(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous month',
        ),
        Text(
          '${_months[month.month - 1]} ${month.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

// ── Monthly totals ──────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.records});
  final List<PayrollModel> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final total =
        records.fold<double>(0, (s, p) => s + p.calculatedNet);
    final paid = records
        .where((p) => p.status == PaymentStatus.paid)
        .fold<double>(0, (s, p) => s + p.calculatedNet);
    final paidCount =
        records.where((p) => p.status == PaymentStatus.paid).length;

    Widget chip(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: color)),
                Text(label,
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        chip('Total payroll', _fmtMoney(total), AppColors.primary),
        const SizedBox(width: 10),
        chip('Paid ($paidCount of ${records.length})', _fmtMoney(paid),
            AppColors.success),
        const SizedBox(width: 10),
        chip('Pending', _fmtMoney(total - paid), AppColors.warning),
      ],
    );
  }
}

// ── One payroll row ─────────────────────────────────────────────────────────
class _PayrollTile extends ConsumerWidget {
  const _PayrollTile({required this.record});
  final PayrollModel record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = record;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          onTap: () => _showPayrollDialog(context, ref, existing: p),
          title: Text(p.employeeName),
          subtitle: Text(
            'Base ${_fmtMoney(p.baseSalary)}'
            '${p.overtime > 0 ? " • OT ${_fmtMoney(p.overtime)}" : ""}'
            '${p.bonuses > 0 ? " • Bonus ${_fmtMoney(p.bonuses)}" : ""}'
            '${p.deductions > 0 ? " • Ded ${_fmtMoney(p.deductions)}" : ""}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtMoney(p.calculatedNet),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Chip(
                    label: Text(p.status.name),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Payslip PDF',
                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                onPressed: () => _downloadPayslip(context, ref, p),
              ),
              if (p.status != PaymentStatus.paid)
                PermissionGate(
                  permission: 'payroll_edit',
                  child: IconButton(
                    tooltip: 'Mark paid',
                    icon: const Icon(Icons.check, size: 20),
                    onPressed: () => ref
                        .read(payrollServiceProvider)
                        .updateStatus(p.id, PaymentStatus.paid),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPayslip(
      BuildContext context, WidgetRef ref, PayrollModel p) async {
    final messenger = ScaffoldMessenger.of(context);
    final employees = ref.read(employeesProvider).valueOrNull ?? const [];
    EmployeeModel? emp;
    for (final e in employees) {
      if (e.id == p.employeeId) {
        emp = e;
        break;
      }
    }
    if (emp == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Employee profile not found for this record.')));
      return;
    }
    final company =
        ref.read(companySettingsProvider).valueOrNull?.companyName ??
            'Company';
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

// ── Add / edit dialog ───────────────────────────────────────────────────────
void _showPayrollDialog(BuildContext context, WidgetRef ref,
    {PayrollModel? existing}) {
  final isEdit = existing != null;
  final formKey = GlobalKey<FormState>();
  final employees = ref.read(employeesProvider).valueOrNull ?? const [];
  final month = ref.read(_payrollMonthProvider);

  String? selectedId = existing?.employeeId;
  final base = TextEditingController(
      text: existing != null ? existing.baseSalary.toStringAsFixed(0) : '');
  final overtime = TextEditingController(
      text: existing != null ? existing.overtime.toStringAsFixed(0) : '0');
  final deductions = TextEditingController(
      text: existing != null ? existing.deductions.toStringAsFixed(0) : '0');
  final bonuses = TextEditingController(
      text: existing != null ? existing.bonuses.toStringAsFixed(0) : '0');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Payroll Record' : 'Add Payroll Record'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdit)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(existing.employeeName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${_months[existing.month - 1]} ${existing.year}'),
                )
              else
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: employees
                      .map((e) => DropdownMenuItem(
                          value: e.id, child: Text(e.fullName)))
                      .toList(),
                  onChanged: (v) => selectedId = v,
                  validator: (v) => v == null ? 'Select employee' : null,
                ),
              TextFormField(
                controller: base,
                decoration: const InputDecoration(labelText: 'Base Salary'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    Validators.positiveNumber(v, 'Base salary') ??
                    Validators.required(v, 'Base salary'),
              ),
              TextFormField(
                controller: overtime,
                decoration: const InputDecoration(labelText: 'Overtime'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: deductions,
                decoration: const InputDecoration(labelText: 'Deductions'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: bonuses,
                decoration: const InputDecoration(labelText: 'Bonuses'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate() || selectedId == null) return;
            final messenger = ScaffoldMessenger.of(ctx);
            try {
              if (isEdit) {
                await ref.read(payrollServiceProvider).update(
                      PayrollModel(
                        id: existing.id,
                        employeeId: existing.employeeId,
                        employeeName: existing.employeeName,
                        month: existing.month,
                        year: existing.year,
                        baseSalary: double.parse(base.text),
                        overtime: double.tryParse(overtime.text) ?? 0,
                        deductions: double.tryParse(deductions.text) ?? 0,
                        bonuses: double.tryParse(bonuses.text) ?? 0,
                        status: existing.status,
                        paidAt: existing.paidAt,
                        notes: existing.notes,
                        createdAt: existing.createdAt,
                      ),
                    );
              } else {
                final emp =
                    employees.firstWhere((e) => e.id == selectedId);
                await ref.read(payrollServiceProvider).createPayroll(
                      PayrollModel(
                        id: '',
                        employeeId: emp.id,
                        employeeName: emp.fullName,
                        month: month.month,
                        year: month.year,
                        baseSalary: double.parse(base.text),
                        overtime: double.tryParse(overtime.text) ?? 0,
                        deductions: double.tryParse(deductions.text) ?? 0,
                        bonuses: double.tryParse(bonuses.text) ?? 0,
                      ),
                    );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              messenger.showSnackBar(
                  SnackBar(content: Text(AppException.from(e).message)));
            }
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    ),
  );
}
