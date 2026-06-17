import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/employee_model.dart';
import '../../../providers/data_providers.dart';

/// Opened from the dashboard "Total Employees" stat card.
/// Two tabs:
///  • Active   — employees currently working (status == active)
///  • All      — every employee since the company was created (incl. left/old)
///
/// A department dropdown filters both tabs (All / IT / Billing / …),
/// auto-populated from existing employees.
class EmployeeOverviewScreen extends ConsumerStatefulWidget {
  const EmployeeOverviewScreen({super.key});

  @override
  ConsumerState<EmployeeOverviewScreen> createState() =>
      _EmployeeOverviewScreenState();
}

const _allDepartments = 'All Departments';

class _EmployeeOverviewScreenState
    extends ConsumerState<EmployeeOverviewScreen> {
  String _selectedDept = _allDepartments;

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_rounded, color: AppColors.heading),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/dashboard'),
          ),
          title: const Text(
            'Total Employees',
            style: TextStyle(
              color: AppColors.heading,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: const TabBar(
            labelColor: AppColors.brandNavy,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.brandNavy,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'All (since start)'),
            ],
          ),
        ),
        body: employees.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppColors.error)),
          ),
          data: (list) {
            // Build the department options from existing employees.
            final departments = <String>{
              for (final e in list)
                if ((e.departmentName?.trim().isNotEmpty ?? false))
                  e.departmentName!.trim(),
            }.toList()
              ..sort();

            // Make sure a previously-selected dept that no longer exists
            // falls back to "All".
            if (_selectedDept != _allDepartments &&
                !departments.contains(_selectedDept)) {
              _selectedDept = _allDepartments;
            }

            bool matchesDept(EmployeeModel e) =>
                _selectedDept == _allDepartments ||
                (e.departmentName?.trim() == _selectedDept);

            final filtered = list.where(matchesDept).toList();
            final active = filtered
                .where((e) => e.status == EmployeeStatus.active)
                .toList();

            return Column(
              children: [
                _DeptFilterBar(
                  departments: departments,
                  selected: _selectedDept,
                  onChanged: (v) => setState(() => _selectedDept = v),
                ),
                const Divider(height: 1, color: AppColors.cardBorder),
                Expanded(
                  child: TabBarView(
                    children: [
                      _EmployeeList(
                        employees: active,
                        emptyText: 'No active employees',
                        caption: _selectedDept == _allDepartments
                            ? 'Currently working in the company'
                            : 'Active in $_selectedDept',
                      ),
                      _EmployeeList(
                        employees: filtered,
                        emptyText: 'No employees yet',
                        caption: _selectedDept == _allDepartments
                            ? 'Everyone since the company started — new & old'
                            : 'All $_selectedDept employees — new & old',
                        showStatus: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeptFilterBar extends StatelessWidget {
  const _DeptFilterBar({
    required this.departments,
    required this.selected,
    required this.onChanged,
  });

  final List<String> departments;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.apartment_rounded,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Text(
            'Department',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selected,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textMuted),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _allDepartments,
                      child: Text(_allDepartments),
                    ),
                    for (final d in departments)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({
    required this.employees,
    required this.emptyText,
    required this.caption,
    this.showStatus = false,
  });

  final List<EmployeeModel> employees;
  final String emptyText;
  final String caption;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Center(
        child: Text(emptyText,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
      );
    }

    return Column(
      children: [
        // Count banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: AppColors.surface,
          child: Row(
            children: [
              Text(
                '${employees.length}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  caption,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = employees[i];
              return _EmployeeTile(employee: e, showStatus: showStatus);
            },
          ),
        ),
      ],
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.showStatus});

  final EmployeeModel employee;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/employees/${employee.id}'),
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            InitialAvatar(name: employee.fullName, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee.position?.isNotEmpty == true
                        ? '${employee.position} · ${employee.departmentName ?? "—"}'
                        : (employee.departmentName ?? employee.email),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showStatus) _statusPill(employee.status),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.active:
        return StatusPill.green('Active');
      case EmployeeStatus.pending:
        return StatusPill.amber('Pending');
      case EmployeeStatus.inactive:
        return StatusPill.red('Inactive');
      case EmployeeStatus.terminated:
        return StatusPill.red('Left');
    }
  }
}
