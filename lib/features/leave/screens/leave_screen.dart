import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
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

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaves = ref.watch(leaveRequestsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Leave Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                PermissionGate(
                  permission: 'leave_create',
                  child: ElevatedButton.icon(
                    onPressed: () => _showRequestDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Request Leave'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: AsyncValueWidget(
                value: leaves,
                onRetry: () => ref.invalidate(leaveRequestsProvider),
                data: (list) => ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => _LeaveTile(leave: list[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    var leaveType = LeaveType.annual;
    var start = DateTime.now().add(const Duration(days: 1));
    var end = start.add(const Duration(days: 1));
    final fmt = DateFormat('yyyy-MM-dd');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Theme(
          data: AppTheme.light(),
          child: AlertDialog(
          title: const Text('Request Leave'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<LeaveType>(
                    initialValue: leaveType,
                    decoration: const InputDecoration(labelText: 'Leave Type'),
                    items: LeaveType.values
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(_leaveTypeLabel(t))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => leaveType = v!),
                  ),
                  // Live entitlement for the picked type (self-request).
                  Consumer(
                    builder: (context, r, _) {
                      final empId =
                          r.read(currentUserProvider).valueOrNull?.employeeId;
                      if (empId == null) return const SizedBox.shrink();
                      final bal = _balanceForType(
                          r.watch(employeeLeaveBalancesProvider(empId)),
                          leaveType);
                      if (bal == null) return const SizedBox.shrink();
                      final reqDays = end.difference(start).inDays + 1;
                      final exceeds = reqDays > bal.remaining;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${_leaveTypeLabel(leaveType)}: '
                            '${bal.remaining} of ${bal.allowance} days left'
                            '${exceeds ? ' • this request exceeds it by ${reqDays - bal.remaining}' : ''}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: (exceeds || bal.overLimit)
                                  ? AppColors.error
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    title: Text('Start: ${fmt.format(start)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: start,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setDialogState(() => start = d);
                    },
                  ),
                  ListTile(
                    title: Text('End: ${fmt.format(end)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: end,
                        firstDate: start,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setDialogState(() => end = d);
                    },
                  ),
                  TextFormField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    maxLines: 3,
                    validator: (v) => Validators.required(v, 'Reason'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (end.isBefore(start)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('End date must be after start')),
                  );
                  return;
                }
                final user = ref.read(currentUserProvider).valueOrNull;
                if (user?.employeeId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Link employee profile first')),
                  );
                  return;
                }
                // Warn (but don't block) if it exceeds the leave balance.
                final reqDays = end.difference(start).inDays + 1;
                final bal = _balanceForType(
                    ref.read(employeeLeaveBalancesProvider(user!.employeeId!)),
                    leaveType);
                if (bal != null && reqDays > bal.remaining) {
                  final proceed = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
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
                        body: '${user.displayName} requested ${leaveType.name} leave',
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
              child: const Text('Submit'),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _LeaveTile extends ConsumerWidget {
  const _LeaveTile({required this.leave});

  final LeaveRequestModel leave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('yyyy-MM-dd');
    Color statusColor;
    switch (leave.status) {
      case LeaveStatus.approved:
        statusColor = AppColors.success;
      case LeaveStatus.rejected:
        statusColor = AppColors.error;
      default:
        statusColor = AppColors.warning;
    }

    final bal = _balanceForType(
      ref.watch(employeeLeaveBalancesProvider(leave.employeeId)),
      leave.leaveType,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          title: Text(leave.employeeName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_leaveTypeLabel(leave.leaveType)} • '
                '${fmt.format(leave.startDate)} → ${fmt.format(leave.endDate)} '
                '(${leave.days}d)',
              ),
              if ((leave.reason ?? '').isNotEmpty) Text(leave.reason!),
              if (bal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    bal.overLimit
                        ? '${_leaveTypeLabel(leave.leaveType)} balance: over by '
                            '${bal.used - bal.allowance} (of ${bal.allowance})'
                        : '${_leaveTypeLabel(leave.leaveType)} balance: '
                            '${bal.remaining} of ${bal.allowance} left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: bal.overLimit ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          isThreeLine: true,
          trailing: leave.status == LeaveStatus.pending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PermissionGate(
                      permission: 'leave_approve',
                      child: IconButton(
                        icon: const Icon(Icons.check, color: AppColors.success),
                        onPressed: () => _approve(ref, context, true),
                      ),
                    ),
                    PermissionGate(
                      permission: 'leave_approve',
                      child: IconButton(
                        icon: const Icon(Icons.close, color: AppColors.error),
                        onPressed: () => _approve(ref, context, false),
                      ),
                    ),
                  ],
                )
              : Chip(
                  label: Text(leave.status.name),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                ),
        ),
      ),
    );
  }

  Future<void> _approve(WidgetRef ref, BuildContext context, bool approve) async {
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
