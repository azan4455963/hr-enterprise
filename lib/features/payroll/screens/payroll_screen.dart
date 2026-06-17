import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/payroll_model.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payroll = ref.watch(payrollProvider);

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
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddPayroll(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Record'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AsyncValueWidget(
                  value: payroll,
                  onRetry: () => ref.invalidate(payrollProvider),
                  data: (list) => list.isEmpty
                      ? const Center(child: Text('No payroll records this month'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final p = list[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: ListTile(
                                  title: Text(p.employeeName),
                                  subtitle: Text(
                                    '${_monthName(p.month)} ${p.year} • Base \$${p.baseSalary.toStringAsFixed(0)}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${p.calculatedNet.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Chip(
                                            label: Text(p.status.name),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          if (p.status != PaymentStatus.paid)
                                            PermissionGate(
                                              permission: 'payroll_edit',
                                              child: IconButton(
                                                icon: const Icon(Icons.check, size: 20),
                                                onPressed: () => ref
                                                    .read(payrollServiceProvider)
                                                    .updateStatus(
                                                      p.id,
                                                      PaymentStatus.paid,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPayroll(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final employees = ref.read(employeesProvider).valueOrNull ?? [];
    String? selectedId;
    final base = TextEditingController();
    final overtime = TextEditingController(text: '0');
    final deductions = TextEditingController(text: '0');
    final bonuses = TextEditingController(text: '0');
    final now = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payroll Record'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: employees
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => selectedId = v,
                  validator: (v) => v == null ? 'Select employee' : null,
                ),
                TextFormField(
                  controller: base,
                  decoration: const InputDecoration(labelText: 'Base Salary'),
                  keyboardType: TextInputType.number,
                  validator: (v) => Validators.positiveNumber(v, 'Base salary') ?? Validators.required(v, 'Base salary'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate() || selectedId == null) return;
              final emp = employees.firstWhere((e) => e.id == selectedId);
              try {
                await ref.read(payrollServiceProvider).createPayroll(
                      PayrollModel(
                        id: '',
                        employeeId: emp.id,
                        employeeName: emp.fullName,
                        month: now.month,
                        year: now.year,
                        baseSalary: double.parse(base.text),
                        overtime: double.tryParse(overtime.text) ?? 0,
                        deductions: double.tryParse(deductions.text) ?? 0,
                        bonuses: double.tryParse(bonuses.text) ?? 0,
                      ),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(AppException.from(e).message)),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
