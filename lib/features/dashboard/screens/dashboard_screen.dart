import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/google_sheet_model.dart';
import '../../../models/payroll_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/google_sheets_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/table_attendance_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);
    final isDirector =
        user != null && user.role == 'manager' && user.departments.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDirector) ...[
            _DirectorBanner(departments: user.departments),
            const SizedBox(height: 16),
          ],
          _StatRow(ref: ref, isWide: isWide).animate().fadeIn(),
          const SizedBox(height: 20),
          _TodayAttendanceTotalCard(ref: ref),
          if (isWide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 16, child: _ChartCard(ref: ref)),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 9,
                    child: canViewSalary
                        ? _PayrollSummaryCard(ref: ref)
                        : const _PlaceholderCard(title: 'Payroll Summary'),
                  ),
                ],
              ),
            )
          else ...[
            _ChartCard(ref: ref),
            const SizedBox(height: 16),
            if (canViewSalary) _PayrollSummaryCard(ref: ref),
          ],
          const SizedBox(height: 20),
          if (isWide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 9, child: _ActivityCard(ref: ref)),
                  const SizedBox(width: 20),
                  Expanded(flex: 16, child: _DepartmentCard(ref: ref)),
                ],
              ),
            )
          else ...[
            _ActivityCard(ref: ref),
            const SizedBox(height: 16),
            _DepartmentCard(ref: ref),
          ],
          const SizedBox(height: 20),
          _SheetInsightsCard(ref: ref),
        ],
      ),
    );
  }
}

/// ── Google Sheet insights (auto-detected status breakdowns) ─────────────
class _SheetInsightsCard extends StatelessWidget {
  const _SheetInsightsCard({required this.ref});
  final WidgetRef ref;

  static const _palette = [
    AppColors.pillGreenFg,
    AppColors.brandBlue,
    AppColors.pillAmberFg,
    AppColors.primary,
    AppColors.pillRedFg,
    AppColors.accent,
  ];

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(sheetSummariesProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Sheet Insights',
            subtitle: 'Live from attached Google Sheets · auto-refreshes.',
            trailing: IconButton(
              tooltip: 'Refresh now',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => ref.invalidate(sheetSummariesProvider),
            ),
          ),
          const SizedBox(height: 8),
          summaries.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('$e',
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.table_chart_outlined,
                          size: 18, color: AppColors.textFaint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No sheets attached yet. Add one under "Sheets".',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/google-sheets'),
                        child: const Text('Add Sheet'),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final s in list) _SheetSummaryBlock(summary: s),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SheetSummaryBlock extends StatelessWidget {
  const _SheetSummaryBlock({required this.summary});
  final SheetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_rounded,
                  size: 16, color: AppColors.brandNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading),
                ),
              ),
              if (!summary.hasError)
                Text('${summary.totalRows} records',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (summary.hasError)
            Text(
              'Could not load — make sure the sheet is published to the web.',
              style: const TextStyle(fontSize: 12, color: AppColors.pillRedFg),
            )
          else if (summary.breakdowns.isEmpty)
            const Text('No status columns detected.',
                style: TextStyle(fontSize: 12, color: AppColors.textFaint))
          else
            for (final b in summary.breakdowns) _BreakdownRow(breakdown: b),
          const Divider(height: 20, color: AppColors.cardBorder),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.breakdown});
  final SheetStatusBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.sortedCounts;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            breakdown.column.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            const Text('No values yet',
                style: TextStyle(fontSize: 12, color: AppColors.textFaint))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _StatusChip(
                    label: entries[i].key,
                    count: entries[i].value,
                    color: _SheetInsightsCard
                        ._palette[i % _SheetInsightsCard._palette.length],
                  ),
                if (breakdown.blank > 0)
                  _StatusChip(
                    label: 'Blank',
                    count: breakdown.blank,
                    color: AppColors.textFaint,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// ── Director banner + quick actions (shown to managers) ─────────────────
class _DirectorBanner extends StatelessWidget {
  const _DirectorBanner({required this.departments});
  final List<String> departments;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.brandNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Director Dashboard',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.heading)),
                    Text(
                      'Managing: ${departments.join(", ")}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickAction(
                  label: 'Find Employee',
                  icon: Icons.person_search_rounded,
                  onTap: () => context.go('/employee-search')),
              _QuickAction(
                  label: 'Add Employee',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: () => context.go('/employees/new')),
              _QuickAction(
                  label: 'Attendance',
                  icon: Icons.event_available_rounded,
                  onTap: () => context.go('/attendance')),
              _QuickAction(
                  label: 'Leave',
                  icon: Icons.beach_access_rounded,
                  onTap: () => context.go('/leave')),
              _QuickAction(
                  label: 'Reports',
                  icon: Icons.bar_chart_rounded,
                  onTap: () => context.go('/reports')),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.brandNavy),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody)),
          ],
        ),
      ),
    );
  }
}

/// ── Stat row ───────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  const _StatRow({required this.ref, required this.isWide});
  final WidgetRef ref;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final employeeCount = ref.watch(employeeCountProvider);
    final stats = ref.watch(attendanceStatsProvider);
    final pendingLeave = ref.watch(pendingLeaveProvider);
    // When an attendance sheet is attached, its figures take priority.
    final sheetAtt = ref.watch(attendanceSheetSummaryProvider).valueOrNull;

    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewEmployees =
        user != null && user.hasPermission('employees_view');

    String fromInt(AsyncValue v, [String Function(dynamic)? map]) => v.when(
          data: (d) => map != null ? map(d) : '$d',
          loading: () => '…',
          error: (_, _) => '0',
        );

    // When the sheet reports a month total, label cards with the month.
    final sheetPeriod = sheetAtt?.periodLabel;
    final sheetFooter =
        sheetPeriod != null ? '$sheetPeriod · from sheet' : 'from sheet';

    // Present card: prefer sheet, else Firestore stats.
    final presentValue = sheetAtt != null
        ? '${sheetAtt.present}'
        : fromInt(stats, (s) => '${s.present}');
    final presentFooter = sheetAtt != null
        ? sheetFooter
        : stats.maybeWhen(
            data: (s) => s.total > 0
                ? '${((s.present / s.total) * 100).round()}% attendance rate'
                : '—',
            orElse: () => '—',
          );

    final absentValue = sheetAtt != null
        ? '${sheetAtt.absent}'
        : fromInt(stats, (s) => '${s.absent}');

    // Fourth card flips to "On Leave" when the sheet reports leave, else
    // keeps showing pending leave approvals.
    final showLeaveFromSheet = sheetAtt != null;

    return StatCardRow(
      isWide: isWide,
      cards: [
        StatCard(
          label: 'Total Employees',
          value: sheetAtt != null
              ? '${sheetAtt.headcount}'
              : fromInt(employeeCount),
          icon: Icons.groups_rounded,
          footer: sheetAtt != null
              ? sheetFooter
              : (canViewEmployees ? 'View details →' : 'Active workforce'),
          onTap: canViewEmployees
              ? () => context.go('/employee-overview')
              : null,
        ),
        StatCard(
          label: 'Present Today',
          value: presentValue,
          icon: Icons.check_circle_outline,
          iconColor: AppColors.pillGreenFg,
          iconBg: AppColors.pillGreenBg,
          footer: presentFooter,
          footerColor: AppColors.pillGreenFg,
          onTap: () => context.go('/attendance'),
        ),
        StatCard(
          label: 'Absent Today',
          value: absentValue,
          icon: Icons.cancel_outlined,
          iconColor: AppColors.pillRedFg,
          iconBg: AppColors.pillRedBg,
          footer: sheetAtt != null ? sheetFooter : 'Not checked in',
          onTap: () => context.go('/attendance'),
        ),
        if (showLeaveFromSheet)
          StatCard(
            label: 'On Leave',
            value: '${sheetAtt.leave}',
            icon: Icons.beach_access_rounded,
            iconColor: AppColors.pillAmberFg,
            iconBg: AppColors.pillAmberBg,
            footer: sheetFooter,
            footerColor: AppColors.pillAmberFg,
            onTap: () => context.go('/leave'),
          )
        else
          StatCard(
            label: 'Pending Approvals',
            value: fromInt(pendingLeave, (l) => '${l.length}'),
            icon: Icons.pending_actions_rounded,
            iconColor: AppColors.pillAmberFg,
            iconBg: AppColors.pillAmberBg,
            footer: 'Requires action',
            footerColor: AppColors.pillRedFg,
            onTap: () => context.go('/leave'),
          ),
      ],
    );
  }
}

/// ── 7-day attendance chart ─────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final chart = ref.watch(weeklyAttendanceChartProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            '7-Day Attendance Trends',
            subtitle: 'Daily workforce presence.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: chart.when(
              data: (data) {
                final maxY = data
                    .map((e) => e.count)
                    .fold<int>(1, (a, b) => a > b ? a : b);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in data)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${d.count}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: (d.count / maxY).clamp(0.04, 1),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.brandBlue,
                                          Color(0xFF60A5FA),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                d.day.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('$e',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Payroll summary ─────────────────────────────────────────────────────
class _PayrollSummaryCard extends StatelessWidget {
  const _PayrollSummaryCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final payroll = ref.watch(payrollProvider);
    return AppCard(
      child: payroll.when(
        data: (list) {
          final total = list.fold(0.0, (s, p) => s + p.calculatedNet);
          final paid = list
              .where((p) => p.status == PaymentStatus.paid)
              .fold(0.0, (s, p) => s + p.calculatedNet);
          final pct = total == 0 ? 0.0 : paid / total;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Payroll Summary',
                subtitle: 'Current month projections.',
              ),
              const SizedBox(height: 18),
              _MoneyTile(
                label: 'Total Budget',
                value: _money(total),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 10),
              _MoneyTile(
                label: 'Paid to Date',
                value: _money(paid),
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Budget Utilization',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody)),
                  Text('${(pct * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandNavy)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.brandBlueSoft,
                  color: AppColors.brandNavy,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: GhostButton(
                  label: 'Review Payroll Reports',
                  onPressed: () => context.go('/payroll'),
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  static String _money(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}

class _MoneyTile extends StatelessWidget {
  const _MoneyTile(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandBlueSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: AppColors.brandBlue),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.heading)),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── Recent activity ─────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(dashboardActivityProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Recent Activity',
            trailing: TextButton(
              onPressed: () => context.go('/notifications'),
              child: const Text('See All'),
            ),
          ),
          const SizedBox(height: 8),
          activity.when(
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No recent activity',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }
              return Column(
                children: [
                  for (final a in items.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                                color: a.dotColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.text,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textBody,
                                        height: 1.4)),
                                if (a.at != null)
                                  Text(_timeAgo(a.at!),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textFaint)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(
                child:
                    Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }
}

/// ── Departmental breakdown table ────────────────────────────────────────
class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentBreakdownProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Departmental Breakdown',
            subtitle: 'Headcount and active status by division.',
          ),
          const SizedBox(height: 14),
          depts.when(
            data: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No departments yet',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }
              return Column(
                children: [
                  const _DeptHeaderRow(),
                  const Divider(height: 16, color: AppColors.cardBorder),
                  for (final d in rows) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(d.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.heading)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('${d.total}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textBody)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: d.pct / 100,
                                    minHeight: 5,
                                    backgroundColor: AppColors.brandBlueSoft,
                                    color: AppColors.pillGreenFg,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${d.pct.round()}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.pillGreenFg)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go('/employees'),
                              child: const Text('Manage'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.cardBorder),
                  ],
                ],
              );
            },
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }
}

class _DeptHeaderRow extends StatelessWidget {
  const _DeptHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.textMuted);
    return const Row(
      children: [
        Expanded(flex: 4, child: Text('DEPARTMENT', style: style)),
        Expanded(flex: 2, child: Text('HEADCOUNT', style: style)),
        Expanded(flex: 3, child: Text('STATUS', style: style)),
        Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.centerRight,
                child: Text('ACTIONS', style: style))),
      ],
    );
  }
}

/// ── Today's attendance — grand total only (detail lives in /attendance) ──
class _TodayAttendanceTotalCard extends StatelessWidget {
  const _TodayAttendanceTotalCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(tableAttendanceTodayProvider);
    if (!today.hasData) return const SizedBox.shrink();

    final dateStr = _fmtToday(today.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () => context.go('/attendance'),
        borderRadius: BorderRadius.circular(14),
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
                    child: Text("Today's Attendance · $dateStr",
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.heading)),
                  ),
                  const Text('By department →',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandBlue)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _TotChip('Present', today.present, AppColors.pillGreenFg,
                      AppColors.pillGreenBg),
                  _TotChip('Late', today.late, AppColors.pillAmberFg,
                      AppColors.pillAmberBg),
                  _TotChip('Leave', today.leave, AppColors.pillBlueFg,
                      AppColors.pillBlueBg),
                  _TotChip('Absent', today.absent, AppColors.pillRedFg,
                      AppColors.pillRedBg),
                  _TotChip('Marked', today.totalPeople, AppColors.textBody,
                      AppColors.canvas),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtToday(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _TotChip extends StatelessWidget {
  const _TotChip(this.label, this.count, this.fg, this.bg);
  final String label;
  final int count;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody)),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: 20),
          const Text('No access', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
