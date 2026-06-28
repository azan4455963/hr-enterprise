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
                      onDirectors: () =>
                          _showDirectors(context, ref, d, user?.id ?? ''),
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

  Future<void> _showDirectors(
    BuildContext context,
    WidgetRef ref,
    DepartmentModel dept,
    String adminId,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => _DirectorsDialog(
        departmentId: dept.id,
        departmentName: dept.name,
        adminId: adminId,
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
    required this.onDirectors,
  });
  final DepartmentModel dept;
  final int employeeCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDirectors;

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
              icon: const Icon(Icons.manage_accounts_outlined,
                  color: AppColors.brandNavy),
              tooltip: 'Directors',
              onPressed: onDirectors,
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

/// Admin dialog: see current directors of a department and add/remove them.
class _DirectorsDialog extends ConsumerWidget {
  const _DirectorsDialog({
    required this.departmentId,
    required this.departmentName,
    required this.adminId,
  });
  final String departmentId;
  final String departmentName;
  final String adminId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final service = ref.read(departmentServiceProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Department Directors',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.heading)),
      content: SizedBox(
        width: 440,
        child: usersAsync.when(
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (users) {
            // Directors of THIS department (matched by department name), and
            // everyone else (candidates).
            final directors = users
                .where((u) =>
                    u.role == 'manager' &&
                    u.departments.contains(departmentName))
                .toList();
            final candidates = users
                .where((u) =>
                    u.role != 'super_admin' &&
                    !(u.role == 'manager' &&
                        u.departments.contains(departmentName)))
                .toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current directors',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
                const SizedBox(height: 6),
                if (directors.isEmpty)
                  const Text('None yet',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textFaint))
                else
                  ...directors.map((u) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.verified_user,
                            color: AppColors.pillGreenFg, size: 20),
                        title: Text(u.displayName ?? u.email,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textBody)),
                        subtitle: Text(u.email,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.error, size: 20),
                          tooltip: 'Remove',
                          onPressed: () => service.removeDirector(departmentId,
                              directorUid: u.id, adminId: adminId),
                        ),
                      )),
                const Divider(height: 20),
                const Text('Assign a new director',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 200,
                  child: candidates.isEmpty
                      ? const Center(
                          child: Text('No other users',
                              style: TextStyle(color: AppColors.textFaint)))
                      : ListView(
                          children: [
                            for (final u in candidates)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: InitialAvatar(
                                    name: u.displayName ?? u.email, size: 30),
                                title: Text(u.displayName ?? u.email,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textBody)),
                                subtitle: Text(
                                    '${u.email} · ${u.role}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                                trailing: TextButton(
                                  onPressed: () => service.assignDirector(
                                      departmentId,
                                      directorUid: u.id,
                                      adminId: adminId),
                                  child: const Text('Make director'),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
