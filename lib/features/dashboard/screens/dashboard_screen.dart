import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/payroll_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';
import '../widgets/employee_search_dialog.dart';
import '../widgets/starfield_background.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    return StarfieldBackground(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 20 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(
              userName: user?.displayName ?? 'User',
              onSearch: () => showEmployeeSearchDialog(context, ref),
              onNotifications: () => context.push('/notifications'),
              unreadCount: ref.watch(unreadNotificationsCountProvider),
              clockText: DateFormat('hh:mm a').format(DateTime.now()),
              dateText: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              avatarLetter: _initial(user?.displayName),
            ).animate().fadeIn(),
            const SizedBox(height: 16),
            _StatGrid(ref: ref).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 14),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 16,
                    child: _WeeklyChartCard(ref: ref),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 10,
                    child: canViewSalary
                        ? _PayrollCard(ref: ref)
                        : const _MyAttendanceCard(),
                  ),
                ],
              )
            else ...[
              _WeeklyChartCard(ref: ref),
              const SizedBox(height: 12),
              canViewSalary ? _PayrollCard(ref: ref) : const _MyAttendanceCard(),
            ],
            const SizedBox(height: 14),
            if (isDesktop)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _DepartmentCard(ref: ref)),
                    const SizedBox(width: 12),
                    Expanded(child: _ActivityCard(ref: ref)),
                    const SizedBox(width: 12),
                    Expanded(child: _TopPerformersCard(ref: ref)),
                  ],
                ),
              )
            else ...[
              _DepartmentCard(ref: ref),
              const SizedBox(height: 12),
              _ActivityCard(ref: ref),
              const SizedBox(height: 12),
              _TopPerformersCard(ref: ref),
            ],
          ],
        ),
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.userName,
    required this.onSearch,
    required this.onNotifications,
    required this.unreadCount,
    required this.clockText,
    required this.dateText,
    required this.avatarLetter,
  });

  final String userName;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final int unreadCount;
  final String clockText;
  final String dateText;
  final String avatarLetter;

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $userName',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$dateText — Live from Firestore',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.premiumTextMuted,
                ),
              ),
            ],
          ),
        ),
        if (isWide) ...[
          InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 14, color: AppColors.premiumTextMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Search employees...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              clockText,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onNotifications,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _AvatarCircle(letter: avatarLetter, size: 32),
        ] else
          Row(
            children: [
              IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.search, color: Colors.white70),
              ),
              IconButton(
                onPressed: onNotifications,
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications_outlined,
                      color: Colors.white70),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final employeeCount = ref.watch(employeeCountProvider);
    final stats = ref.watch(attendanceStatsProvider);
    final pendingLeave = ref.watch(pendingLeaveProvider);
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isWide ? 4 : 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: isWide ? 1.55 : 1.35,
      children: [
        _PremiumStatCard(
          color: AppColors.primary,
          icon: Icons.people_rounded,
          value: employeeCount.when(
            data: (c) => '$c',
            loading: () => '…',
            error: (_, __) => '0',
          ),
          label: 'Total Employees',
        ),
        _PremiumStatCard(
          color: AppColors.success,
          icon: Icons.check_circle_outline,
          value: stats.when(
            data: (s) => '${s.present}',
            loading: () => '…',
            error: (_, __) => '0',
          ),
          label: 'Present Today',
        ),
        _PremiumStatCard(
          color: AppColors.error,
          icon: Icons.cancel_outlined,
          value: stats.when(
            data: (s) => '${s.absent}',
            loading: () => '…',
            error: (_, __) => '0',
          ),
          label: 'Absent Today',
        ),
        _PremiumStatCard(
          color: AppColors.warning,
          icon: Icons.beach_access_rounded,
          value: pendingLeave.when(
            data: (l) => '${l.length}',
            loading: () => '…',
            error: (_, __) => '0',
          ),
          label: 'Pending Leave',
        ),
      ],
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  const _PremiumStatCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color.withValues(alpha: 0.9), size: 17),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.premiumTextMuted),
          ),
        ],
      ),
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.premiumGlassSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.premiumGlassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WeeklyChartCard extends StatelessWidget {
  const _WeeklyChartCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final chart = ref.watch(weeklyAttendanceChartProvider);
    return _PremiumPanel(
      title: 'Attendance — Last 7 Days',
      child: SizedBox(
        height: 100,
        child: chart.when(
          data: (data) {
            final maxY = data.map((e) => e.count).fold<int>(
                  0,
                  (a, b) => a > b ? a : b,
                );
            final maxH = maxY == 0 ? 1.0 : maxY.toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in data)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: d.count / maxH,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: d.count == 0
                                        ? [
                                            AppColors.primary
                                                .withValues(alpha: 0.25),
                                            AppColors.primary
                                                .withValues(alpha: 0.15),
                                          ]
                                        : const [
                                            Color(0xFF818CF8),
                                            Color(0xFF6366F1),
                                          ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.day,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.premiumTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (e, _) => Text('$e', style: const TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }
}

class _PayrollCard extends StatelessWidget {
  const _PayrollCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final payroll = ref.watch(payrollProvider);
    return _PremiumPanel(
      title: 'Payroll This Month',
      child: payroll.when(
        data: (list) {
          final total = list.fold(0.0, (s, p) => s + p.calculatedNet);
          final paid = list.where((p) => p.status == PaymentStatus.paid).length;
          final pct = list.isEmpty ? 0.0 : paid / list.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFA5B4FC),
                ),
              ),
              Text(
                '${list.length} records total',
                style: TextStyle(fontSize: 10, color: AppColors.premiumTextMuted),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(pct * 100).round()}% paid',
                    style: const TextStyle(fontSize: 10, color: AppColors.success),
                  ),
                  Text(
                    '${((1 - pct) * 100).round()}% pending',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.premiumTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PayrollMiniStat(
                      value: '$paid',
                      label: 'Paid',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PayrollMiniStat(
                      value: '${list.length - paid}',
                      label: 'Pending',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}

class _PayrollMiniStat extends StatelessWidget {
  const _PayrollMiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppColors.premiumTextMuted),
          ),
        ],
      ),
    );
  }
}

class _MyAttendanceCard extends ConsumerWidget {
  const _MyAttendanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayAttendanceProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    return _PremiumPanel(
      title: 'My Attendance Today',
      child: today.when(
        data: (list) {
          final mine = list
              .where((a) => a.employeeId == user?.employeeId)
              .toList();
          if (mine.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No check-in recorded yet.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.premiumTextSoft,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push('/attendance'),
                  child: const Text('Mark attendance'),
                ),
              ],
            );
          }
          final r = mine.first;
          return Text(
            'Status: ${r.status.name}\n'
            'In: ${r.checkIn != null ? DateFormat.Hm().format(r.checkIn!) : '—'}\n'
            'Out: ${r.checkOut != null ? DateFormat.Hm().format(r.checkOut!) : '—'}',
            style: TextStyle(fontSize: 11, color: AppColors.premiumTextSoft),
          );
        },
        loading: () => const CircularProgressIndicator(strokeWidth: 2),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentBreakdownProvider);
    return _PremiumPanel(
      title: 'Department Breakdown',
      child: depts.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Text(
              'No departments yet',
              style: TextStyle(fontSize: 11, color: AppColors.premiumTextSoft),
            );
          }
          return Column(
            children: [
              for (final d in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            d.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            '${d.pct.round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.premiumTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: d.pct / 100,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          color: d.color,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const CircularProgressIndicator(strokeWidth: 2),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(dashboardActivityProvider);
    return _PremiumPanel(
      title: 'Live Activity',
      child: activity.when(
        data: (items) {
          if (items.isEmpty) {
            return Text(
              'No recent activity',
              style: TextStyle(fontSize: 11, color: AppColors.premiumTextSoft),
            );
          }
          return Column(
            children: [
              for (final a in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: a.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.text,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                            ),
                            if (a.at != null)
                              Text(
                                _timeAgo(a.at!),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.premiumTextMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const CircularProgressIndicator(strokeWidth: 2),
        error: (e, _) => Text('$e'),
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

class _TopPerformersCard extends StatelessWidget {
  const _TopPerformersCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final performers = ref.watch(topPerformersProvider);
    return _PremiumPanel(
      title: 'Top Performers',
      child: performers.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Text(
              'No employee data yet',
              style: TextStyle(fontSize: 11, color: AppColors.premiumTextSoft),
            );
          }
          return Column(
            children: [
              for (final p in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => context.push('/employees/${p.employee.id}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        _AvatarCircle(
                          letter: p.employee.firstName.isNotEmpty
                              ? p.employee.firstName[0].toUpperCase()
                              : '?',
                          size: 26,
                          gradient: _performerGradient(rows.indexOf(p)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.employee.fullName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                p.employee.departmentName ??
                                    p.employee.position ??
                                    '—',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.premiumTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${p.score}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const CircularProgressIndicator(strokeWidth: 2),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  LinearGradient _performerGradient(int index) {
    const gradients = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFFF59E0B), Color(0xFFD97706)],
      [Color(0xFFEF4444), Color(0xFFDC2626)],
    ];
    final g = gradients[index % gradients.length];
    return LinearGradient(colors: g);
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.letter,
    required this.size,
    this.gradient,
  });

  final String letter;
  final double size;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient ??
            const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}
