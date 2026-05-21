import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/employee_model.dart';
import '../../../providers/data_providers.dart';

Future<void> showEmployeeSearchDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _EmployeeSearchDialog(),
  );
}

class _EmployeeSearchDialog extends ConsumerStatefulWidget {
  const _EmployeeSearchDialog();

  @override
  ConsumerState<_EmployeeSearchDialog> createState() =>
      _EmployeeSearchDialogState();
}

class _EmployeeSearchDialogState extends ConsumerState<_EmployeeSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    return AlertDialog(
      title: const Text('Search employees'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Name, email, department...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: employees.when(
                data: (list) {
                  final filtered = _filter(list, _query);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No employees found'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final emp = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          child: Text(emp.firstName.isNotEmpty
                              ? emp.firstName[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(emp.fullName),
                        subtitle: Text(
                          '${emp.position ?? '—'} • ${emp.departmentName ?? 'No dept'}',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/employees/${emp.id}');
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
          ],
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

  List<EmployeeModel> _filter(List<EmployeeModel> list, String q) {
    if (q.isEmpty) return list.take(20).toList();
    return list
        .where((e) {
          final hay = '${e.fullName} ${e.email} ${e.departmentName ?? ''} '
                  '${e.position ?? ''}'
              .toLowerCase();
          return hay.contains(q);
        })
        .take(30)
        .toList();
  }
}
