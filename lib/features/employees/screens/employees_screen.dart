import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Employees',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                PermissionGate(
                  permission: 'employees_create',
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/employees/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Employee'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: employees.when(
                data: (list) => list.isEmpty
                    ? const Center(child: Text('No employees yet'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final emp = list[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                            onTap: () => context.push('/employees/${emp.id}'),
                            padding: const EdgeInsets.all(16),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.2),
                                backgroundImage: emp.profilePictureUrl != null
                                    ? NetworkImage(emp.profilePictureUrl!)
                                    : null,
                                child: emp.profilePictureUrl == null
                                    ? Text(emp.firstName[0])
                                    : null,
                              ),
                              title: Text(emp.fullName),
                              subtitle: Text(
                                '${emp.position ?? 'N/A'} • ${emp.departmentName ?? 'No Dept'}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Chip(
                                    label: Text(emp.status.name),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (canViewSalary && emp.salary != null)
                                    Text(
                                      '\$${emp.salary!.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          )
                              .animate()
                              .fadeIn(delay: (i * 50).ms);
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
