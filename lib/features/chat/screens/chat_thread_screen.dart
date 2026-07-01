import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/conversation_model.dart';
import '../../../models/notification_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_providers.dart';
import '../../../providers/service_providers.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final convo = ref.watch(conversationProvider(widget.conversationId)).valueOrNull;
    final messages =
        ref.watch(conversationMessagesProvider(widget.conversationId));
    if (me == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final amParticipant = convo?.hasParticipant(me.id) ?? false;
    final title = convo == null
        ? 'Chat'
        : (amParticipant
            ? convo.otherName(me.id)
            : convo.participantNames.values.join('  ↔  '));

    return Column(
      children: [
        // Header
        Container(
          color: AppColors.canvas,
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/messages'),
              ),
              InitialAvatar(name: title, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading),
                    overflow: TextOverflow.ellipsis),
              ),
              if (!amParticipant)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pillAmberBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 13, color: AppColors.pillAmberFg),
                      SizedBox(width: 5),
                      Text('Monitoring',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pillAmberFg)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
        // Messages
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text(AppException.from(e).message,
                    style: const TextStyle(color: AppColors.textMuted))),
            data: (list) {
              if (list.isEmpty) {
                return const Center(
                  child: Text('No messages yet — say hello 👋',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }
              final ordered = list.reversed.toList(); // newest first
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: ordered.length,
                itemBuilder: (_, i) {
                  final m = ordered[i];
                  final mine = m.senderId == me.id;
                  return _Bubble(msg: m, mine: mine, showSender: !amParticipant);
                },
              );
            },
          ),
        ),
        // Composer
        if (amParticipant)
          _composer(me, convo)
        else
          Container(
            width: double.infinity,
            color: AppColors.canvas,
            padding: const EdgeInsets.all(14),
            child: const Text(
              'Read-only — you are monitoring this conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _composer(UserModel me, ConversationModel? convo) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(me, convo),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.canvas,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.brandNavy,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : () => _send(me, convo),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(UserModel me, ConversationModel? convo) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatServiceProvider).sendMessage(
            conversationId: widget.conversationId,
            sender: me,
            text: text,
          );
      if (convo != null) {
        final otherId = convo.otherId(me.id);
        await ref.read(messagingServiceProvider).notifyRole(
              title: 'New message from ${me.displayName ?? me.email}',
              body: text,
              type: NotificationType.system,
              userId: otherId,
            );
      }
    } catch (e) {
      _ctrl.text = text;
      messenger
          .showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.msg, required this.mine, required this.showSender});
  final ChatMessageModel msg;
  final bool mine;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final time = msg.sentAt != null ? DateFormat('HH:mm').format(msg.sentAt!) : '';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: mine ? AppColors.brandNavy : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          border: mine ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSender && !mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(msg.senderName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandBlue)),
              ),
            Text(msg.text,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: mine ? Colors.white : AppColors.textBody)),
            const SizedBox(height: 3),
            Text(time,
                style: TextStyle(
                    fontSize: 9.5,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}
