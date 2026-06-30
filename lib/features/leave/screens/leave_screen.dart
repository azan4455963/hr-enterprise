import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/export_menu.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/leave_model.dart';
import '../../../models/notification_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/leave_balance_providers.dart';
import '../../../providers/service_providers.dart';

/// Title-cased leave type label, e.g. "Annual".
String _leaveTypeLabel(LeaveType t) =>
    t.name.isEmpty ? t.name : '${t.name[0].toUpperCase()}${t.name.substring(1)}';

/// Find one type's balance in a list, or null if that type isn't tracked.
LeaveBalance? _balanceForType(List<LeaveBalance> balances, LeaveType type) {
  for (final b in balances) {
    if (b.type == type) return b;
  }
  return null;
}

/// A small icon per leave type for the request cards / dropdown.
IconData _leaveTypeIcon(LeaveType t) {
  switch (t.name) {
    case 'annual':
      return Icons.beach_access_rounded;
    case 'sick':
      return Icons.medical_services_outlined;
    case 'casual':
      return Icons.weekend_outlined;
    case 'unpaid':
      return Icons.money_off_rounded;
    case 'maternity':
    case 'paternity':
      return Icons.child_friendly_outlined;
    default:
      return Icons.event_note_outlined;
  }
}

StatusPill _statusPill(LeaveStatus s) {
  switch (s) {
    case LeaveStatus.approved:
      return StatusPill.green('Approved');
    case LeaveStatus.rejected:
      return StatusPill.red('Rejected');
    case LeaveStatus.cancelled:
      return StatusPill.red('Cancelled');
    case LeaveStatus.pending:
      return StatusPill.amber('Pending');
  }
}

InputDecoration _dec(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      isDense: true,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final leaves = ref.watch(leaveRequestsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final empId = user?.employeeId;
    final balances = (empId != null && empId.isNotEmpty)
        ? ref.watch(employeeLeaveBalancesProvider(empId))
        : const <LeaveBalance>[];

    final totalAllowance = balances.fold<int>(0, (s, b) => s + b.allowance);
    final totalUsed = balances.fold<int>(0, (s, b) => s + b.used);
    final remaining = totalAllowance - totalUsed;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 28 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: PageHeading(
                    title: 'Leave Management',
                    subtitle: 'Track your balance and manage leave requests.',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PermissionGate(
                      permission: 'reports_export',
                      child: ExportMenuButton(
                        onExportPdf: () async {
                          final data =
                              await ref.read(leaveRequestsProvider.future);
                          await ref
                              .read(exportServiceProvider)
                              .shareLeavePdf(data);
                        },
                        onExportExcel: () async {
                          final data =
                              await ref.read(leaveRequestsProvider.future);
                          final bytes = await ref
                              .read(exportServiceProvider)
                              .buildLeaveExcel(data);
                          await saveXlsxBytes(bytes, 'leave.xlsx');
                        },
                      ),
                    ),
                    PermissionGate(
                      permission: 'leave_create',
                      child: PrimaryButton(
                        label: 'Request Leave',
                        icon: Icons.add,
                        onPressed: () => _showRequestDialog(context, ref),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── My leave balance ──────────────────────────────────────────
            if (balances.isNotEmpty) ...[
              _BalanceCards(
                isWide: isWide,
                allowance: totalAllowance,
                used: totalUsed,
                remaining: remaining,
              ),
              const SizedBox(height: 24),
            ],

            // ── Recent requests ───────────────────────────────────────────
            const SectionTitle(
              'Recent Requests',
              subtitle: 'Latest leave activity across the team.',
            ),
            const SizedBox(height: 12),
            leaves.when(
              data: (list) {
                if (list.isEmpty) return _emptyRequests();
                return Column(
                  children: [
                    for (final l in list)
                      _LeaveCard(leave: l, isWide: isWide),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(AppException.from(e).message,
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyRequests() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            SizedBox(height: 12),
            Icon(Icons.event_busy_outlined,
                size: 40, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text('No leave requests yet',
                style: TextStyle(
                    color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
          ],
        ),
      );

  // ── Request leave dialog ───────────────────────────────────────────────
  void _showRequestDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    var leaveType = LeaveType.annual;
    var start = DateTime.now().add(const Duration(days: 1));
    var end = start.add(const Duration(days: 1));
    final fmt = DateFormat('EEE, dd MMM yyyy');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Theme(
          data: AppTheme.light(),
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            title: const Row(
              children: [
                Icon(Icons.event_available_rounded, color: AppColors.brandNavy),
                SizedBox(width: 10),
                Text('Request Leave',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandNavy)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      DropdownButtonFormField<LeaveType>(
                        initialValue: leaveType,
                        decoration: _dec('Leave Type', Icons.category_outlined),
                        items: LeaveType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Icon(_leaveTypeIcon(t),
                                          size: 16,
                                          color: AppColors.textMuted),
                                      const SizedBox(width: 8),
                                      Text(_leaveTypeLabel(t)),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => leaveType = v!),
                      ),
                      // Live entitlement for the picked type (self-request).
                      Consumer(
                        builder: (context, r, _) {
                          final empId = r
                              .read(currentUserProvider)
                              .valueOrNull
                              ?.employeeId;
                          if (empId == null) return const SizedBox.shrink();
                          final bal = _balanceForType(
                              r.watch(employeeLeaveBalancesProvider(empId)),
                              leaveType);
                          if (bal == null) return const SizedBox.shrink();
                          final reqDays = end.difference(start).inDays + 1;
                          final exceeds = reqDays > bal.remaining;
                          final color = (exceeds || bal.overLimit)
                              ? AppColors.error
                              : AppColors.pillGreenFg;
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                      exceeds
                                          ? Icons.warning_amber_rounded
                                          : Icons.info_outline_rounded,
                                      size: 16,
                                      color: color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      exceeds
                                          ? '${bal.remaining} of ${bal.allowance} days left • exceeds by ${reqDays - bal.remaining}'
                                          : '${bal.remaining} of ${bal.allowance} days left',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: color),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Start Date',
                              value: fmt.format(start),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: start,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (d != null) {
                                  setDialogState(() {
                                    start = d;
                                    if (end.isBefore(start)) end = start;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateField(
                              label: 'End Date',
                              value: fmt.format(end),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: end,
                                  firstDate: start,
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (d != null) setDialogState(() => end = d);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: reasonController,
                        decoration: _dec('Reason', Icons.notes_rounded),
                        maxLines: 3,
                        validator: (v) => Validators.required(v, 'Reason'),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (end.isBefore(start)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('End date must be after start')),
                    );
                    return;
                  }
                  final user = ref.read(currentUserProvider).valueOrNull;
                  if (user?.employeeId == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Link employee profile first')),
                    );
                    return;
                  }
                  // Warn (but don't block) if it exceeds the leave balance.
                  final reqDays = end.difference(start).inDays + 1;
                  final bal = _balanceForType(
                      ref.read(
                          employeeLeaveBalancesProvider(user!.employeeId!)),
                      leaveType);
                  if (bal != null && reqDays > bal.remaining) {
                    final proceed = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => Theme(
                        data: AppTheme.light(),
                        child: AlertDialog(
                          title: const Text('Exceeds leave balance'),
                          content: Text(
                            '${_leaveTypeLabel(leaveType)} balance is '
                            '${bal.remaining} day(s) left, but this request is '
                            '$reqDays day(s). Submit anyway?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Submit anyway'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (proceed != true) return;
                  }
                  try {
                    await ref.read(leaveServiceProvider).createRequest(
                          LeaveRequestModel(
                            id: '',
                            employeeId: user.employeeId!,
                            employeeName: user.displayName ?? user.email,
                            startDate: start,
                            endDate: end,
                            leaveType: leaveType,
                            reason: reasonController.text,
                          ),
                        );
                    await ref.read(messagingServiceProvider).notifyRole(
                          title: 'New leave request',
                          body:
                              '${user.displayName} requested ${leaveType.name} leave',
                          type: NotificationType.leave,
                          targetRoles: [RolePermissions.superAdmin],
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(AppException.from(e).message)),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three KPI cards at the top: total allocation, taken, remaining.
class _BalanceCards extends StatelessWidget {
  const _BalanceCards({
    required this.isWide,
    required this.allowance,
    required this.used,
    required this.remaining,
  });

  final bool isWide;
  final int allowance;
  final int used;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _BalanceCard(
        label: 'Total Allocation',
        days: allowance,
        footer: 'Annual entitlement',
        icon: Icons.event_note_outlined,
        accent: AppColors.brandBlue,
        accentBg: AppColors.brandBlueSoft,
      ),
      _BalanceCard(
        label: 'Leaves Taken',
        days: used,
        footer: 'Used this year',
        icon: Icons.flight_takeoff_rounded,
        accent: AppColors.pillAmberFg,
        accentBg: AppColors.pillAmberBg,
      ),
      _BalanceCard(
        label: 'Remaining Balance',
        days: remaining < 0 ? 0 : remaining,
        footer: '$used of $allowance days used',
        icon: Icons.verified_outlined,
        accent: AppColors.pillGreenFg,
        accentBg: AppColors.pillGreenBg,
        progress:
            allowance > 0 ? remaining.clamp(0, allowance) / allowance : 0,
        highlight: true,
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.days,
    required this.footer,
    required this.icon,
    required this.accent,
    required this.accentBg,
    this.progress,
    this.highlight = false,
  });

  final String label;
  final int days;
  final String footer;
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final double? progress;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: 0.6)
              : AppColors.cardBorder,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$days',
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.heading,
                      height: 1)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text('days',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.cardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(footer,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: highlight ? accent : AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// One leave request row, styled to match the design.
class _LeaveCard extends ConsumerWidget {
  const _LeaveCard({required this.leave, required this.isWide});

  final LeaveRequestModel leave;
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('yyyy-MM-dd');
    final canApprove = ref
            .watch(currentUserProvider)
            .valueOrNull
            ?.hasPermission('leave_approve') ??
        false;
    final dateText =
        '${df.format(leave.startDate)} → ${df.format(leave.endDate)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            InitialAvatar(name: leave.employeeName, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(leave.employeeName,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(_leaveTypeIcon(leave.leaveType),
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('${_leaveTypeLabel(leave.leaveType)} Leave',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (!isWide) ...[
                    const SizedBox(height: 6),
                    _dateRow(dateText, leave.days),
                  ],
                ],
              ),
            ),
            if (isWide) ...[
              const SizedBox(width: 12),
              Expanded(child: _dateRow(dateText, leave.days, center: true)),
            ],
            const SizedBox(width: 12),
            _trailing(ref, context, canApprove),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(String dateText, int days, {bool center = false}) {
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 13, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(dateText,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('$days Day${days == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _trailing(WidgetRef ref, BuildContext context, bool canApprove) {
    final pill = _statusPill(leave.status);
    if (leave.status == LeaveStatus.pending && canApprove) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          pill,
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniIconButton(
                icon: Icons.check_rounded,
                color: AppColors.pillGreenFg,
                tooltip: 'Approve',
                onTap: () => _approve(ref, context, true),
              ),
              const SizedBox(width: 6),
              _MiniIconButton(
                icon: Icons.close_rounded,
                color: AppColors.pillRedFg,
                tooltip: 'Reject',
                onTap: () => _approve(ref, context, false),
              ),
            ],
          ),
        ],
      );
    }
    return pill;
  }

  Future<void> _approve(
      WidgetRef ref, BuildContext context, bool approve) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    try {
      if (approve) {
        await ref.read(leaveServiceProvider).approve(leave.id, user.id);
        await ref.read(messagingServiceProvider).notifyRole(
              title: 'Leave approved',
              body: 'Your ${leave.leaveType.name} leave was approved',
              type: NotificationType.leave,
              userId: leave.employeeId,
            );
      } else {
        await ref.read(leaveServiceProvider).reject(leave.id, user.id);
        await ref.read(messagingServiceProvider).notifyRole(
              title: 'Leave rejected',
              body: 'Your leave request was rejected',
              type: NotificationType.leave,
              userId: leave.employeeId,
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

/// Small round icon button used for approve / reject.
class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

/// A tap-to-pick date field shown as a bordered input with a calendar icon.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
        ),
        child: Text(value,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
