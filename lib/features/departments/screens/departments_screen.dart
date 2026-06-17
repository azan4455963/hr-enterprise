import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/department_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

/// Admin-only: create, rename, delete departments and see how many employees
/// each one has. (Assigning directors comes in the next step.)
class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final departments = ref.watch(departmentsProvider);
    final employees = ref.watch(employeesProvider).valueOrNull ?? [];
    final user = ref.watch(currentUserProvider).valueOrNull;

    int countFor(String name) =>
        employees.where((e) => (e.departmentName ?? '').trim() == name).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeading(
                  title: 'Departments',
                  subtitle:
                      'Create and manage company departments. Admin only.',
                ),
              ),
              PrimaryButton(
                label: 'Add Department',
                icon: Icons.add,
                onPressed: () => _showAddEdit(context, ref, user?.id ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 22),
          departments.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: AppColors.error)),
            data: (list) {
              if (list.isEmpty) {
                return const AppCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('No departments yet. Tap "Add Department".',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final d in list)
                    _DeptCard(
                      dept: d,
                      employeeCount: countFor(d.name),
                      onEdit: () =>
                          _showAddEdit(context, ref, user?.id ?? '', dept: d),
                      onDelete: () =>
                          _confirmDelete(context, ref, d, user?.id ?? ''),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEdit(
    BuildContext context,
    WidgetRef ref,
    String userId, {
    DepartmentModel? dept,
  }) async {
    final controller = TextEditingController(text: dept?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final isEdit = dept != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Rename Department' : 'Add Department',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Department name',
              hintText: 'e.g. IT, Marketing, Billing',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: isEdit ? 'Save' : 'Add',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = controller.text.trim();
              final service = ref.read(departmentServiceProvider);
              try {
                if (isEdit) {
                  await service.rename(dept.id, name: name, userId: userId);
                } else {
                  await service.create(name: name, userId: userId);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DepartmentModel dept,
    String userId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Department',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove "${dept.name}"? Employees keep their records but lose this '
          'department label.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(departmentServiceProvider)
          .delete(dept.id, userId: userId);
    }
  }
}

class _DeptCard extends StatelessWidget {
  const _DeptCard({
    required this.dept,
    required this.employeeCount,
    required this.onEdit,
    required this.onDelete,
  });
  final DepartmentModel dept;
  final int employeeCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.apartment_rounded,
                  color: AppColors.brandNavy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dept.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.heading)),
                  const SizedBox(height: 2),
                  Text(
                    '$employeeCount employee(s)'
                    '${dept.directorIds.isNotEmpty ? " · ${dept.directorIds.length} director(s)" : ""}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.brandNavy),
              tooltip: 'Rename',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
