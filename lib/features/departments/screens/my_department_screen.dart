import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/attendance_model.dart';
import '../../../models/employee_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';

/// A Director's home for the department(s) they manage: headcount, today's
/// attendance, and the employee list — all scoped to their departments.
class MyDepartmentScreen extends ConsumerWidget {
  const MyDepartmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final employeesAsync = ref.watch(employeesProvider);
    final todayAsync = ref.watch(todayAttendanceProvider);

    final depts = user?.departments ?? const <String>[];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PageHeading(
                  title: 'My Department',
                  subtitle: depts.isEmpty
                      ? 'Your assigned department'
                      : 'Managing: ${depts.join(", ")}',
                ),
              ),
              PrimaryButton(
                label: 'Add Employee',
                icon: Icons.person_add_alt_1,
                onPressed: () => context.go('/employees/new'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: AppColors.error)),
            data: (employees) {
              final today =
                  todayAsync.valueOrNull ?? const <AttendanceModel>[];
              final presentIds = today
                  .where((a) =>
                      a.status == AttendanceStatus.present ||
                      a.status == AttendanceStatus.late)
                  .map((a) => a.employeeId)
                  .toSet();
              final onLeave = today
                  .where((a) => a.status == AttendanceStatus.onLeave)
                  .length;
              final present = presentIds.length;
              final total = employees.length;
              final absent = (total - present - onLeave).clamp(0, total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatCardRow(
                    isWide: isWide,
                    cards: [
                      StatCard(
                        label: 'Employees',
                        value: '$total',
                        icon: Icons.groups_rounded,
                        footer: depts.join(", "),
                      ),
                      StatCard(
                        label: 'Present Today',
                        value: '$present',
                        icon: Icons.check_circle_outline,
                        iconColor: AppColors.pillGreenFg,
                        iconBg: AppColors.pillGreenBg,
                        footer: 'Checked in',
                        footerColor: AppColors.pillGreenFg,
                      ),
                      StatCard(
                        label: 'Absent',
                        value: '$absent',
                        icon: Icons.cancel_outlined,
                        iconColor: AppColors.pillRedFg,
                        iconBg: AppColors.pillRedBg,
                        footer: 'Not checked in',
                      ),
                      StatCard(
                        label: 'On Leave',
                        value: '$onLeave',
                        icon: Icons.beach_access_rounded,
                        iconColor: AppColors.pillAmberFg,
                        iconBg: AppColors.pillAmberBg,
                        footer: 'Today',
                        footerColor: AppColors.pillAmberFg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Team Members',
                            subtitle: 'Everyone in your department(s).'),
                        const SizedBox(height: 12),
                        if (employees.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No employees yet',
                                style: TextStyle(color: AppColors.textMuted)),
                          )
                        else
                          for (final e in employees)
                            _MemberRow(
                              employee: e,
                              present: presentIds.contains(e.id),
                              onTap: () => context.go('/employees/${e.id}'),
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.employee,
    required this.present,
    required this.onTap,
  });
  final EmployeeModel employee;
  final bool present;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            InitialAvatar(name: employee.fullName, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.fullName,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading)),
                  Text(
                    '${employee.position ?? "—"} · ${employee.departmentName ?? "—"}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            present
                ? StatusPill.green('Present')
                : StatusPill.red('Not in'),
          ],
        ),
      ),
    );
  }
}
