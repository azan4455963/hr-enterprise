import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/reminders_providers.dart';

/// Upcoming HR reminders: birthdays, work anniversaries, CNIC expiries and
/// contract endings — computed live from employee dates.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final reminders = ref.watch(remindersProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Reminders',
            subtitle:
                'Upcoming birthdays, work anniversaries, CNIC expiries and '
                'contract endings.',
          ),
          const SizedBox(height: 18),
          if (reminders.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Column(
                  children: [
                    const Icon(Icons.notifications_none_rounded,
                        size: 48, color: AppColors.textFaint),
                    const SizedBox(height: 10),
                    Text(
                      'Nothing due in the next $reminderWindowDays days.',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add Date of Birth, CNIC Expiry or Contract End dates on '
                      'an employee to see reminders here.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.textFaint),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final r in reminders) _ReminderTile(reminder: r),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(reminder.type);
    final fmt = DateFormat('EEE, dd MMM yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_typeIcon(reminder.type), color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reminder.employeeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppColors.heading)),
                  const SizedBox(height: 2),
                  Text(
                    '${_typeLabel(reminder.type)}  ·  ${fmt.format(reminder.date)}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            _whenChip(reminder.daysUntil),
          ],
        ),
      ),
    );
  }

  Widget _whenChip(int days) {
    final (label, color) = _when(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }

  (String, Color) _when(int days) {
    if (days < 0) return ('${-days}d overdue', AppColors.error);
    if (days == 0) return ('Today', AppColors.warning);
    if (days == 1) return ('Tomorrow', AppColors.warning);
    if (days <= 7) return ('in ${days}d', AppColors.warning);
    return ('in ${days}d', AppColors.brandBlue);
  }

  String _typeLabel(ReminderType t) => switch (t) {
        ReminderType.birthday => 'Birthday',
        ReminderType.anniversary => 'Work anniversary',
        ReminderType.cnicExpiry => 'CNIC expiry',
        ReminderType.contractEnd => 'Contract ends',
      };

  IconData _typeIcon(ReminderType t) => switch (t) {
        ReminderType.birthday => Icons.cake_rounded,
        ReminderType.anniversary => Icons.workspace_premium_rounded,
        ReminderType.cnicExpiry => Icons.badge_rounded,
        ReminderType.contractEnd => Icons.event_busy_rounded,
      };

  Color _typeColor(ReminderType t) => switch (t) {
        ReminderType.birthday => AppColors.brandBlue,
        ReminderType.anniversary => AppColors.success,
        ReminderType.cnicExpiry => AppColors.warning,
        ReminderType.contractEnd => AppColors.error,
      };
}
