import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/attendance_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(todayAttendanceProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canMark = user != null
        ? ref.watch(canMarkAttendanceProvider(user.id))
        : const AsyncValue.data(false);
    final hasEmployee = canMark.valueOrNull ?? false;
    final fmt = DateFormat('HH:mm');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                PermissionGate(
                  permission: 'attendance_edit',
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/attendance/qr-display'),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Show QR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasEmployee) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _manualAction(ref, context, checkIn: true),
                    icon: const Icon(Icons.login),
                    label: const Text('Check In'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _manualAction(ref, context, checkIn: false),
                    icon: const Icon(Icons.logout),
                    label: const Text('Check Out'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/attendance/scan'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else
              const GlassCard(
                child: Text(
                  'Link your user account to an employee profile to record attendance.',
                ),
              ),
            Text(
              "Today's logs",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AsyncValueWidget(
                value: attendance,
                onRetry: () => ref.invalidate(todayAttendanceProvider),
                data: (list) => list.isEmpty
                    ? const Center(child: Text('No attendance records today'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) =>
                            _AttendanceTile(record: list[i], fmt: fmt),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manualAction(
    WidgetRef ref,
    BuildContext context, {
    required bool checkIn,
  }) async {
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
          SnackBar(
            content: Text(checkIn ? 'Checked in' : 'Checked out'),
          ),
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

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record, required this.fmt});

  final AttendanceModel record;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (record.status) {
      case AttendanceStatus.present:
        statusColor = AppColors.success;
      case AttendanceStatus.late:
        statusColor = AppColors.warning;
      case AttendanceStatus.absent:
        statusColor = AppColors.error;
      default:
        statusColor = AppColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          leading: Icon(Icons.person, color: statusColor),
          title: Text(record.employeeName ?? record.employeeId),
          subtitle: Text(
            'In: ${record.checkIn != null ? fmt.format(record.checkIn!) : '-'} | '
            'Out: ${record.checkOut != null ? fmt.format(record.checkOut!) : '-'} | '
            '${record.attendanceMethod.name}',
          ),
          trailing: Chip(
            label: Text(record.status.name),
            backgroundColor: statusColor.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}
