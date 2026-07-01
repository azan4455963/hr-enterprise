import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/permissions.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';
import 'data_providers.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// The signed-in user's conversations (newest first).
final myConversationsProvider =
    StreamProvider<List<ConversationModel>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return Stream.value(const []);
  return ref.watch(chatServiceProvider).watchMyConversations(me.id);
});

/// Every conversation — admin read-only monitor.
final allConversationsProvider =
    StreamProvider<List<ConversationModel>>((ref) {
  return ref.watch(chatServiceProvider).watchAll();
});

final conversationProvider =
    StreamProvider.family<ConversationModel?, String>((ref, id) {
  return ref.watch(chatServiceProvider).watchConversation(id);
});

final conversationMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, id) {
  return ref.watch(chatServiceProvider).watchMessages(id);
});

/// Who the signed-in user is allowed to start a chat with:
/// - Admin  → anyone
/// - Director → admins + employees in their department(s)
/// - Employee → admins + the director(s) managing their department
final chatRecipientsProvider = Provider<List<UserModel>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  final all = ref.watch(usersProvider).valueOrNull ?? const [];
  if (me == null) return const [];

  final others = all.where((u) => u.id != me.id && u.isActive).toList();
  bool isAdmin(UserModel u) => RolePermissions.isSuperAdmin(u.role);
  bool isDirector(UserModel u) => u.role == RolePermissions.manager;
  bool isEmployee(UserModel u) => u.role == RolePermissions.employee;

  List<UserModel> result;
  if (RolePermissions.isSuperAdmin(me.role)) {
    result = others;
  } else if (me.role == RolePermissions.manager) {
    final myDepts = me.departments.toSet();
    result = others
        .where((u) =>
            isAdmin(u) ||
            (isEmployee(u) &&
                (u.departmentName != null) &&
                myDepts.contains(u.departmentName)))
        .toList();
  } else {
    final myDept = me.departmentName;
    result = others
        .where((u) =>
            isAdmin(u) ||
            (isDirector(u) &&
                myDept != null &&
                u.departments.contains(myDept)))
        .toList();
  }
  result.sort((a, b) =>
      (a.displayName ?? a.email).compareTo(b.displayName ?? b.email));
  return result;
});
