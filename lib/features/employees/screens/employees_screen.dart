import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/employee_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

const _allDepartments = 'All Departments';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String _selectedDept = _allDepartments;
  bool _activeOnly = false;

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canCreate = user?.hasPermission('employees_create') ?? false;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageHeading(
                  title: 'Employee Directory',
                  subtitle:
                      'Manage your workforce, update profiles, and track employment status.',
                ),
              ),
              if (canCreate)
                PrimaryButton(
                  label: 'Add Employee',
                  icon: Icons.person_add_alt_1,
                  onPressed: () => context.go('/employees/new'),
                ),
            ],
          ),
          const SizedBox(height: 22),
          employees.when(
            data: (list) => _StatRow(list: list, isWide: isWide),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _DeptDropdown(
                      departments: _departmentsFrom(employees.valueOrNull),
                      selected: _selectedDept,
                      onChanged: (v) => setState(() => _selectedDept = v),
                    ),
                    const SizedBox(width: 10),
                    _ToggleChip(
                      label: 'Active Only',
                      selected: _activeOnly,
                      onTap: () => setState(() => _activeOnly = !_activeOnly),
                    ),
                    const Spacer(),
                    if (isWide)
                      GhostButton(
                        label: 'Export',
                        icon: Icons.download_outlined,
                        onPressed: () => context.go('/reports'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 8),
                employees.when(
                  data: (all) {
                    final list = _applyFilters(all);
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          all.isEmpty
                              ? 'No employees yet'
                              : 'No employees match the selected filters',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        if (isWide) const _TableHeader(),
                        if (isWide)
                          const Divider(height: 16, color: AppColors.cardBorder),
                        for (var i = 0; i < list.length; i++)
                          _EmployeeRow(
                            emp: list[i],
                            isWide: isWide,
                            canViewSalary: canViewSalary,
                            onTap: () =>
                                context.go('/employees/${list[i].id}'),
                          ).animate().fadeIn(delay: (i * 30).ms),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Distinct, sorted department names present in the employee list.
  List<String> _departmentsFrom(List<EmployeeModel>? list) {
    if (list == null) return const [];
    final set = <String>{
      for (final e in list)
        if ((e.departmentName?.trim().isNotEmpty ?? false))
          e.departmentName!.trim(),
    };
    final result = set.toList()..sort();
    return result;
  }

  List<EmployeeModel> _applyFilters(List<EmployeeModel> all) {
    return all.where((e) {
      if (_activeOnly && e.status != EmployeeStatus.active) return false;
      if (_selectedDept != _allDepartments &&
          e.departmentName?.trim() != _selectedDept) {
        return false;
      }
      return true;
    }).toList();
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.list, required this.isWide});
  final List<EmployeeModel> list;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final total = list.length;
    final active =
        list.where((e) => e.status == EmployeeStatus.active).length;
    final pending =
        list.where((e) => e.status == EmployeeStatus.pending).length;
    final resigned =
        list.where((e) => e.status == EmployeeStatus.terminated).length;

    return StatCardRow(
      isWide: isWide,
      cards: [
        StatCard(
          label: 'Total Employees',
          value: '$total',
          icon: Icons.groups_rounded,
          footer: 'All records',
        ),
        StatCard(
          label: 'Active Staff',
          value: '$active',
          icon: Icons.badge_outlined,
          iconColor: AppColors.brandBlue,
          iconBg: AppColors.brandBlueSoft,
          footer: total > 0 ? '${((active / total) * 100).round()}% of total' : '—',
        ),
        StatCard(
          label: 'In Onboarding',
          value: '$pending',
          icon: Icons.how_to_reg_outlined,
          iconColor: AppColors.pillGreenFg,
          iconBg: AppColors.pillGreenBg,
          footer: 'Joining soon',
        ),
        StatCard(
          label: 'Resigned',
          value: '$resigned',
          icon: Icons.logout_rounded,
          iconColor: AppColors.pillRedFg,
          iconBg: AppColors.pillRedBg,
          footer: 'Terminated',
        ),
      ],
    );
  }
}

/// Working department filter dropdown (auto-populated from employees).
class _DeptDropdown extends StatelessWidget {
  const _DeptDropdown({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 16, color: AppColors.textMuted),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
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
    );
  }
}

/// A toggleable filter chip (e.g. "Active Only").
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandNavy : AppColors.canvas,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.brandNavy : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_box_rounded : Icons.check_box_outline_blank,
              size: 16,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.textMuted);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('EMPLOYEE NAME', style: style)),
          Expanded(flex: 2, child: Text('EMP ID', style: style)),
          Expanded(flex: 3, child: Text('DEPARTMENT', style: style)),
          Expanded(flex: 3, child: Text('DESIGNATION', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('ACTIONS', style: style))),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({
    required this.emp,
    required this.isWide,
    required this.canViewSalary,
    required this.onTap,
  });

  final EmployeeModel emp;
  final bool isWide;
  final bool canViewSalary;
  final VoidCallback onTap;

  StatusPill get _pill {
    switch (emp.status) {
      case EmployeeStatus.active:
        return StatusPill.green('ACTIVE');
      case EmployeeStatus.inactive:
      case EmployeeStatus.terminated:
        return StatusPill.red(emp.status.name.toUpperCase());
      case EmployeeStatus.pending:
        return StatusPill.amber('PENDING');
    }
  }

  Widget _avatarName() {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.brandBlueSoft,
          backgroundImage: emp.profilePictureUrl != null
              ? NetworkImage(emp.profilePictureUrl!)
              : null,
          child: emp.profilePictureUrl == null
              ? Text(
                  emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.brandBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emp.fullName,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandNavy),
                  overflow: TextOverflow.ellipsis),
              Text(emp.email,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final empId =
        '#EMP-${emp.id.length >= 4 ? emp.id.substring(0, 4).toUpperCase() : emp.id.toUpperCase()}';

    if (!isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: _avatarName()),
                _pill,
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 5, child: _avatarName()),
                Expanded(
                  flex: 2,
                  child: Text(empId,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textBody)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(emp.departmentName ?? '—',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textBody)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(emp.position ?? '—',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textBody)),
                ),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _pill)),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: onTap,
                      icon: const Icon(Icons.more_horiz,
                          color: AppColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
      ],
    );
  }
}
