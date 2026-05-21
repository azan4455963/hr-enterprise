import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/notification_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final user = ref.read(currentUserProvider).valueOrNull;
                    if (user != null) {
                      await ref
                          .read(notificationServiceProvider)
                          .markAllRead(user);
                    }
                  },
                  child: const Text('Mark all read'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: AsyncValueWidget(
                value: notifications,
                onRetry: () => ref.invalidate(notificationsProvider),
                data: (list) => list.isEmpty
                    ? const Center(child: Text('No notifications'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final n = list[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              onTap: () => ref
                                  .read(notificationServiceProvider)
                                  .markAsRead(n.id),
                              child: ListTile(
                                leading: Icon(
                                  _iconForType(n.type),
                                  color: n.isRead
                                      ? Colors.grey
                                      : AppColors.primary,
                                ),
                                title: Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight: n.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(n.body),
                                trailing: n.isRead
                                    ? null
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.attendance:
        return Icons.access_time;
      case NotificationType.leave:
        return Icons.beach_access;
      case NotificationType.payroll:
        return Icons.payments;
      case NotificationType.announcement:
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }
}
