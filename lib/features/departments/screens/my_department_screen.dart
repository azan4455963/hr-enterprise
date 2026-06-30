import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/attendance_model.dart';
import '../../../models/employee_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

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
              final todayByEmp = <String, AttendanceStatus>{
                for (final a in today) a.employeeId: a.status,
              };
              final canMark = user?.hasPermission('attendance_edit') ?? false;

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
                        SectionTitle('Team Members',
                            subtitle: canMark
                                ? "Tap a status to mark today's attendance."
                                : 'Everyone in your department(s).'),
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
                              current: todayByEmp[e.id],
                              canMark: canMark,
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

/// Label + colour for an attendance status (null = not marked yet).
({String label, Color color}) _statusMeta(AttendanceStatus? s) {
  switch (s) {
    case AttendanceStatus.present:
      return (label: 'Present', color: AppColors.pillGreenFg);
    case AttendanceStatus.late:
      return (label: 'Late', color: AppColors.pillAmberFg);
    case AttendanceStatus.onLeave:
      return (label: 'Leave', color: AppColors.pillBlueFg);
    case AttendanceStatus.absent:
      return (label: 'Absent', color: AppColors.pillRedFg);
    case AttendanceStatus.halfDay:
      return (label: 'Half day', color: AppColors.pillAmberFg);
    case null:
      return (label: 'Mark', color: AppColors.textMuted);
  }
}

class _MemberRow extends ConsumerStatefulWidget {
  const _MemberRow({
    required this.employee,
    required this.current,
    required this.canMark,
    required this.onTap,
  });
  final EmployeeModel employee;
  final AttendanceStatus? current;
  final bool canMark;
  final VoidCallback onTap;

  @override
  ConsumerState<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends ConsumerState<_MemberRow> {
  bool _busy = false;

  Future<void> _mark(AttendanceStatus status) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(attendanceServiceProvider).markToday(
            employeeId: widget.employee.id,
            employeeName: widget.employee.fullName,
            departmentName: widget.employee.departmentName,
            status: status,
          );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            InitialAvatar(name: e.fullName, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.fullName,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading)),
                  Text(
                    '${e.position ?? "—"} · ${e.departmentName ?? "—"}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.canMark)
              _StatusDropdown(
                  current: widget.current, busy: _busy, onChanged: _mark)
            else
              _readonlyPill(widget.current),
          ],
        ),
      ),
    );
  }

  Widget _readonlyPill(AttendanceStatus? s) {
    final m = _statusMeta(s);
    if (s == null) return StatusPill.red('Not in');
    return StatusPill(m.label,
        bg: m.color.withValues(alpha: 0.12), fg: m.color);
  }
}

/// Tappable status pill → opens a menu to set today's attendance.
class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.current,
    required this.busy,
    required this.onChanged,
  });
  final AttendanceStatus? current;
  final bool busy;
  final ValueChanged<AttendanceStatus> onChanged;

  static const _options = [
    AttendanceStatus.present,
    AttendanceStatus.late,
    AttendanceStatus.onLeave,
    AttendanceStatus.absent,
  ];

  @override
  Widget build(BuildContext context) {
    final m = _statusMeta(current);
    return PopupMenuButton<AttendanceStatus>(
      enabled: !busy,
      tooltip: "Mark today's attendance",
      color: AppColors.surface,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final s in _options)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: _statusMeta(s).color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(_statusMeta(s).label,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textBody)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: m.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: m.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: m.color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 7),
            Text(m.label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: m.color)),
            Icon(Icons.arrow_drop_down, size: 18, color: m.color),
          ],
        ),
      ),
    );
  }
}
