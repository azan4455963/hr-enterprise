import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/employee_model.dart';
import '../../../providers/data_providers.dart';

/// Full-page employee search (sidebar entry). Type a name and open the
/// employee's complete 360° profile.
class EmployeeSearchScreen extends ConsumerStatefulWidget {
  const EmployeeSearchScreen({super.key});

  @override
  ConsumerState<EmployeeSearchScreen> createState() =>
      _EmployeeSearchScreenState();
}

class _EmployeeSearchScreenState extends ConsumerState<EmployeeSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final employees = ref.watch(employeesProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Employee Search',
            subtitle:
                'Type a name to open a complete profile — attendance, leave, payroll and more.',
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, department or designation…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 16),
                employees.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('$e',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                  data: (list) {
                    final filtered = _filter(list, _query);
                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Text('No employees found',
                            style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    return Column(
                      children: [
                        for (final emp in filtered)
                          _ResultTile(
                            emp: emp,
                            onTap: () => context.push('/employees/${emp.id}'),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<EmployeeModel> _filter(List<EmployeeModel> list, String q) {
    if (q.isEmpty) return list.take(20).toList();
    return list.where((e) {
      final hay = '${e.fullName} ${e.email} ${e.departmentName ?? ''} '
              '${e.position ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).take(50).toList();
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.emp, required this.onTap});
  final EmployeeModel emp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              InitialAvatar(name: emp.fullName, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.heading)),
                    const SizedBox(height: 2),
                    Text(
                      '${emp.position ?? '—'} · ${emp.departmentName ?? 'No department'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
