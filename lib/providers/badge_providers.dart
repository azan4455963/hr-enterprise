import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/permissions.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'chat_providers.dart';
import 'data_providers.dart';
import 'data_table_providers.dart';
import 'reminders_providers.dart';

/// How many items have a createdAt newer than the user's last-seen time for
/// [module]. If they've never opened it, fall back to the last 30 days so items
/// created before their first visit (e.g. a table a director just made) still
/// surface; opening the page then sets a precise baseline and clears the badge.
int _newSince(UserModel? user, String module, Iterable<DateTime?> createdAts) {
  final since = user?.lastSeen[module] ??
      DateTime.now().subtract(const Duration(days: 30));
  var n = 0;
  for (final c in createdAts) {
    if (c != null && c.isAfter(since)) n++;
  }
  return n;
}

/// Conversations with a message from someone else the user hasn't read.
final unreadMessagesCountProvider = Provider<int>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return 0;
  final convos = ref.watch(myConversationsProvider).valueOrNull ?? const [];
  var n = 0;
  for (final c in convos) {
    if (c.unreadFor(me.id)) n++;
  }
  return n;
});

/// New employees added since the user last opened Employees.
final newEmployeesCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || !user.hasPermission('employees_view')) return 0;
  final emps = ref.watch(employeesProvider).valueOrNull ?? const [];
  return _newSince(user, 'employees', emps.map((e) => e.createdAt));
});

/// New tables since the user last opened Tables (e.g. a director created one).
final newTablesCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || !user.hasPermission('tables_manage')) return 0;
  final tables = ref.watch(dataTablesProvider).valueOrNull ?? const [];
  return _newSince(user, 'tables', tables.map((t) => t.createdAt));
});

/// New departments since the user last opened Departments.
final newDepartmentsCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || !user.hasPermission('departments_manage')) return 0;
  final depts = ref.watch(departmentsProvider).valueOrNull ?? const [];
  return _newSince(user, 'departments', depts.map((d) => d.createdAt));
});

/// Pending feature-access requests (shown in Users & Roles; admin only).
final accessRequestsBadgeProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || !RolePermissions.isSuperAdmin(user.role)) return 0;
  return (ref.watch(pendingAccessRequestsProvider).valueOrNull ?? const [])
      .length;
});

/// Reminders due within the reminder window.
final remindersBadgeProvider = Provider<int>((ref) {
  return ref.watch(remindersProvider).length;
});
