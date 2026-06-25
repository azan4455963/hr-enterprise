import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/attendance_model.dart';
import '../../../models/leave_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/google_sheets_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/table_attendance_providers.dart';

/// Selected department for the sheet-based attendance section.
final attendanceDeptProvider = StateProvider<String>((ref) => _allDepts);
const _allDepts = 'All Departments';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(todayAttendanceProvider);
    final leaves = ref.watch(leaveRequestsProvider);
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canManage = user?.hasPermission('attendance_edit') ?? false;
    final hasEmployee =
        user != null && (ref.watch(canMarkAttendanceProvider(user.id)).valueOrNull ?? false);

    return DefaultTabController(
      length: 2,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 28 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: PageHeading(
                    title: 'Attendance & Leaves',
                    subtitle:
                        'Monitor daily logs and manage employee leave requests.',
                  ),
                ),
                if (canManage)
                  PrimaryButton(
                    label: 'Generate Check-in QR',
                    icon: Icons.qr_code_2,
                    onPressed: () => context.go('/attendance/qr-display'),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _StatRow(ref: ref, isWide: isWide),
            const SizedBox(height: 16),
            const _TableAttendanceSection(),
            _DeptAttendanceSection(isWide: isWide),
            if (hasEmployee) _MyActions(ref: ref),
            if (hasEmployee) const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.brandNavy,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorColor: AppColors.brandNavy,
                    labelStyle:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: 'Attendance Log'),
                      Tab(text: 'Leave Requests'),
                    ],
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 420,
                      child: TabBarView(
                        children: [
                          _AttendanceLog(attendance: attendance, isWide: isWide),
                          _LeaveList(
                              leaves: leaves, isWide: isWide, ref: ref),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.ref, required this.isWide});
  final WidgetRef ref;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayAttendanceProvider);
    final pendingLeave = ref.watch(pendingLeaveProvider);
    // In-app attendance tables take priority for today's figures.
    final tableAtt = ref.watch(tableAttendanceTodayProvider);
    final hasTableAtt = tableAtt.hasData;

    final list = today.valueOrNull ?? const <AttendanceModel>[];
    final present = hasTableAtt
        ? tableAtt.present
        : list
            .where((a) =>
                a.status == AttendanceStatus.present ||
                a.status == AttendanceStatus.late)
            .length;
    final late = hasTableAtt
        ? tableAtt.late
        : list.where((a) => a.status == AttendanceStatus.late).length;
    final onLeave = hasTableAtt
        ? tableAtt.leave
        : list.where((a) => a.status == AttendanceStatus.onLeave).length;
    final pending = pendingLeave.valueOrNull?.length ?? 0;

    return StatCardRow(
      isWide: isWide,
      cards: [
        StatCard(
          label: 'Present Today',
          value: '$present',
          icon: Icons.how_to_reg_outlined,
          iconColor: AppColors.pillGreenFg,
          iconBg: AppColors.pillGreenBg,
          footer: 'Checked in',
          footerColor: AppColors.pillGreenFg,
        ),
        StatCard(
          label: 'Late Arrivals',
          value: '$late',
          icon: Icons.alarm,
          iconColor: AppColors.pillRedFg,
          iconBg: AppColors.pillRedBg,
          footer: 'Requires review',
        ),
        StatCard(
          label: 'On Leave',
          value: '$onLeave',
          icon: Icons.event_busy_outlined,
          footer: 'Scheduled absence',
        ),
        StatCard(
          label: 'Pending Requests',
          value: '$pending',
          icon: Icons.pending_actions_outlined,
          iconColor: AppColors.pillAmberFg,
          iconBg: AppColors.pillAmberBg,
          footer: 'View leave requests',
          footerColor: AppColors.brandBlue,
        ),
      ],
    );
  }
}

/// Department-filtered attendance pulled from attached Google Sheets.
/// Sheets named like "Billing Attendance Jun" / "IT Attendance Jun" are grouped
/// by department; the dropdown lets you view one department or all combined.
class _DeptAttendanceSection extends ConsumerWidget {
  const _DeptAttendanceSection({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(allAttendanceSheetSummariesProvider);

    return summaries.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();

        final depts = <String>{for (final s in list) s.department}.toList()
          ..sort();
        var selected = ref.watch(attendanceDeptProvider);
        if (selected != _allDepts && !depts.contains(selected)) {
          selected = _allDepts;
        }

        final filtered = selected == _allDepts
            ? list
            : list.where((s) => s.department == selected).toList();
        final combined =
            combineAttendanceSummaries(filtered, department: selected);

        return Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: SectionTitle(
                          'Attendance by Department',
                          subtitle: 'From attached sheets · auto-updates.',
                        ),
                      ),
                      _DeptDropdown(
                        departments: depts,
                        selected: selected,
                        onChanged: (v) =>
                            ref.read(attendanceDeptProvider.notifier).state = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StatCardRow(
                    isWide: isWide,
                    cards: [
                      StatCard(
                        label: 'Employees',
                        value: '${combined.headcount}',
                        icon: Icons.groups_rounded,
                        footer: combined.periodLabel ?? selected,
                      ),
                      StatCard(
                        label: 'Present',
                        value: '${combined.present}',
                        icon: Icons.check_circle_outline,
                        iconColor: AppColors.pillGreenFg,
                        iconBg: AppColors.pillGreenBg,
                        footer: combined.periodLabel ?? 'from sheet',
                        footerColor: AppColors.pillGreenFg,
                      ),
                      StatCard(
                        label: 'Absent',
                        value: '${combined.absent}',
                        icon: Icons.cancel_outlined,
                        iconColor: AppColors.pillRedFg,
                        iconBg: AppColors.pillRedBg,
                        footer: combined.periodLabel ?? 'from sheet',
                      ),
                      StatCard(
                        label: 'On Leave',
                        value: '${combined.leave}',
                        icon: Icons.beach_access_rounded,
                        iconColor: AppColors.pillAmberFg,
                        iconBg: AppColors.pillAmberBg,
                        footer: combined.periodLabel ?? 'from sheet',
                        footerColor: AppColors.pillAmberFg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
          ),
          items: [
            const DropdownMenuItem(value: _allDepts, child: Text(_allDepts)),
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

class _MyActions extends StatelessWidget {
  const _MyActions({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('My attendance:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody)),
          PrimaryButton(
            label: 'Check In',
            icon: Icons.login,
            color: AppColors.pillGreenFg,
            onPressed: () => _manual(ref, context, checkIn: true),
          ),
          GhostButton(
            label: 'Check Out',
            icon: Icons.logout,
            onPressed: () => _manual(ref, context, checkIn: false),
          ),
          PrimaryButton(
            label: 'Scan QR',
            icon: Icons.qr_code_scanner,
            onPressed: () => context.go('/attendance/scan'),
          ),
        ],
      ),
    );
  }

  Future<void> _manual(WidgetRef ref, BuildContext context,
      {required bool checkIn}) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    try {
      final settings = await ref.read(companySettingsProvider.future);
      final service = ref.read(attendanceServiceProvider);
      if (checkIn) {
        await service.checkIn(
          uid: user.id,
          employeeName: user.displayName ?? user.email,
          settings: settings,
        );
      } else {
        await service.checkOut(
          uid: user.id,
          employeeName: user.displayName ?? user.email,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(checkIn ? 'Checked in' : 'Checked out')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }
}

class _AttendanceLog extends StatelessWidget {
  const _AttendanceLog({required this.attendance, required this.isWide});
  final AsyncValue<List<AttendanceModel>> attendance;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat('hh:mm a');
    final df = DateFormat('MMM d, yyyy');
    return attendance.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('No attendance records today',
                style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return Column(
          children: [
            if (isWide) const _LogHeader(),
            if (isWide) const Divider(height: 16, color: AppColors.cardBorder),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.cardBorder),
                itemBuilder: (_, i) {
                  final r = list[i];
                  final isLate = r.status == AttendanceStatus.late;
                  final pill = isLate
                      ? StatusPill.red('Late')
                      : (r.status == AttendanceStatus.present
                          ? StatusPill.green('On Time')
                          : StatusPill.blue(r.status.name));
                  final inTime = r.checkIn != null ? tf.format(r.checkIn!) : '—';
                  final outTime =
                      r.checkOut != null ? tf.format(r.checkOut!) : '—';
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              InitialAvatar(
                                  name: r.employeeName ?? r.employeeId,
                                  size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(r.employeeName ?? r.employeeId,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.heading),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        if (isWide)
                          Expanded(
                            flex: 3,
                            child: Text(df.format(r.date),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textBody)),
                          ),
                        Expanded(
                          flex: 2,
                          child: Text(inTime,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isLate
                                      ? AppColors.pillRedFg
                                      : AppColors.textBody)),
                        ),
                        if (isWide)
                          Expanded(
                            flex: 2,
                            child: Text(outTime,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textBody)),
                          ),
                        Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: pill)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader();
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
          Expanded(flex: 4, child: Text('EMPLOYEE', style: style)),
          Expanded(flex: 3, child: Text('DATE', style: style)),
          Expanded(flex: 2, child: Text('CLOCK IN', style: style)),
          Expanded(flex: 2, child: Text('CLOCK OUT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }
}

class _LeaveList extends StatelessWidget {
  const _LeaveList(
      {required this.leaves, required this.isWide, required this.ref});
  final AsyncValue<List<LeaveRequestModel>> leaves;
  final bool isWide;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d');
    final canApprove =
        ref.watch(currentUserProvider).valueOrNull?.hasPermission('leave_approve') ??
            false;
    return leaves.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('No leave requests',
                style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: AppColors.cardBorder),
          itemBuilder: (_, i) {
            final l = list[i];
            final pill = switch (l.status) {
              LeaveStatus.approved => StatusPill.green('Approved'),
              LeaveStatus.rejected => StatusPill.red('Rejected'),
              LeaveStatus.cancelled => StatusPill.red('Cancelled'),
              LeaveStatus.pending => StatusPill.amber('Pending'),
            };
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  InitialAvatar(name: l.employeeName, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.employeeName,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.heading)),
                        Text(
                          '${l.leaveType.name} • ${l.days} day(s) • ${df.format(l.startDate)}–${df.format(l.endDate)}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  pill,
                  if (canApprove && l.status == LeaveStatus.pending) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: AppColors.pillGreenFg),
                      onPressed: () => _decide(ref, l, true),
                      tooltip: 'Approve',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel,
                          color: AppColors.pillRedFg),
                      onPressed: () => _decide(ref, l, false),
                      tooltip: 'Reject',
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Future<void> _decide(
      WidgetRef ref, LeaveRequestModel l, bool approve) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final service = ref.read(leaveServiceProvider);
    if (approve) {
      await service.approve(l.id, user.id);
    } else {
      await service.reject(l.id, user.id);
    }
  }
}

/// ── Today's attendance, department-wise, pulled live from in-app tables ──
class _TableAttendanceSection extends ConsumerWidget {
  const _TableAttendanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(tableAttendanceTodayProvider);
    if (!today.hasData) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    size: 18, color: AppColors.brandNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today by Department · ${DateFormat('dd MMM yyyy').format(today.date)}",
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Live from department attendance tables.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            // Header
            const Row(
              children: [
                Expanded(flex: 4, child: _Hdr('DEPARTMENT')),
                Expanded(flex: 2, child: _Hdr('PRESENT')),
                Expanded(flex: 2, child: _Hdr('LATE')),
                Expanded(flex: 2, child: _Hdr('LEAVE')),
                Expanded(flex: 2, child: _Hdr('ABSENT')),
              ],
            ),
            const Divider(height: 16, color: AppColors.cardBorder),
            for (final d in today.departments) ...[
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(d.department,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading)),
                  ),
                  Expanded(
                      flex: 2,
                      child: Text('${d.present}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pillGreenFg))),
                  Expanded(
                      flex: 2,
                      child: Text('${d.late}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.pillAmberFg))),
                  Expanded(
                      flex: 2,
                      child: Text('${d.leave}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.pillBlueFg))),
                  Expanded(
                      flex: 2,
                      child: Text('${d.absent}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.pillRedFg))),
                ],
              ),
              const Divider(height: 18, color: AppColors.cardBorder),
            ],
            // Totals
            Row(
              children: [
                const Expanded(
                    flex: 4,
                    child: Text('Total',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.heading))),
                Expanded(
                    flex: 2,
                    child: Text('${today.present}',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pillGreenFg))),
                Expanded(
                    flex: 2,
                    child: Text('${today.late}',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pillAmberFg))),
                Expanded(
                    flex: 2,
                    child: Text('${today.leave}',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pillBlueFg))),
                Expanded(
                    flex: 2,
                    child: Text('${today.absent}',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pillRedFg))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  const _Hdr(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textMuted));
}
