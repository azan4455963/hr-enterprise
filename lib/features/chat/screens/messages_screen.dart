import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/conversation_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_providers.dart';

String chatShortTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  return DateFormat(sameDay ? 'HH:mm' : 'dd MMM').format(t);
}

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _monitor = false;

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final isAdmin = RolePermissions.isSuperAdmin(me.role);
    final showMonitor = isAdmin && _monitor;
    final convos = showMonitor
        ? ref.watch(allConversationsProvider)
        : ref.watch(myConversationsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageHeading(
                  title: 'Messages',
                  subtitle: 'Chat with your team.',
                ),
              ),
              PrimaryButton(
                label: 'New chat',
                icon: Icons.add_comment_outlined,
                onPressed: () => _newChat(me),
              ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 16),
            _MonitorToggle(
              monitor: _monitor,
              onChanged: (v) => setState(() => _monitor = v),
            ),
          ],
          const SizedBox(height: 16),
          convos.when(
            loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('$e',
                style: const TextStyle(color: AppColors.error)),
            data: (list) {
              if (list.isEmpty) {
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      const Icon(Icons.forum_outlined,
                          size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        showMonitor
                            ? 'No conversations yet.'
                            : 'No chats yet — start one with "New chat".',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final c in list)
                    _ConvoTile(
                      convo: c,
                      myUid: me.id,
                      monitor: showMonitor,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _newChat(UserModel me) async {
    final recipients = ref.read(chatRecipientsProvider);
    final picked = await showDialog<UserModel>(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.light(),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New chat',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 380,
            child: recipients.isEmpty
                ? const Text('No one available to message yet.',
                    style: TextStyle(color: AppColors.textMuted))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final u in recipients)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: InitialAvatar(
                              name: u.displayName ?? u.email, size: 38),
                          title: Text(u.displayName ?? u.email,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            '${RolePermissions.roleLabel(u.role)}'
                            '${(u.departmentName ?? "").isNotEmpty ? " · ${u.departmentName}" : ""}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                          onTap: () => Navigator.pop(ctx, u),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final id = await ref
        .read(chatServiceProvider)
        .openConversation(me: me, other: picked);
    if (mounted) context.go('/messages/$id');
  }
}

class _MonitorToggle extends StatelessWidget {
  const _MonitorToggle({required this.monitor, required this.onChanged});
  final bool monitor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool value, IconData icon) {
      final selected = monitor == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textBody),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textBody)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('My chats', false, Icons.person_outline_rounded),
          seg('Monitor all', true, Icons.visibility_outlined),
        ],
      ),
    );
  }
}

class _ConvoTile extends StatelessWidget {
  const _ConvoTile(
      {required this.convo, required this.myUid, required this.monitor});
  final ConversationModel convo;
  final String myUid;
  final bool monitor;

  @override
  Widget build(BuildContext context) {
    final title = monitor
        ? convo.participantNames.values.join('  ↔  ')
        : convo.otherName(myUid);
    final avatarName =
        monitor ? title : convo.otherName(myUid);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.go('/messages/${convo.id}'),
        borderRadius: BorderRadius.circular(12),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              InitialAvatar(name: avatarName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heading),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (monitor)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.visibility_outlined,
                                size: 14, color: AppColors.textFaint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      convo.lastMessage ?? 'No messages yet',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(chatShortTime(convo.lastMessageAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textFaint)),
            ],
          ),
        ),
      ),
    );
  }
}
