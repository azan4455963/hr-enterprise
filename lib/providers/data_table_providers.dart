import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/permissions.dart';
import '../models/data_table_model.dart';
import '../services/data_table_service.dart';
import 'auth_provider.dart';

final dataTableServiceProvider = Provider<DataTableService>((ref) {
  return DataTableService();
});

/// Custom tables (newest first). A director only sees tables tagged to a
/// department they manage; admins see all.
final dataTablesProvider = StreamProvider<List<DataTableModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final service = ref.watch(dataTableServiceProvider);
  if (user != null && user.role == RolePermissions.manager) {
    return service.watchTables(departmentNames: user.departments);
  }
  return service.watchTables();
});

/// A single table, live.
final dataTableProvider =
    StreamProvider.family<DataTableModel?, String>((ref, id) {
  return ref.watch(dataTableServiceProvider).watchTable(id);
});

/// Match for an employee in a custom table.
typedef TableMatchResult = ({String tableName, String tableId, List<String> columns, List<List<String>> matchingRows});

/// Search all custom tables for rows containing the employee's name or email.
final employeeTableMatchesProvider =
    FutureProvider.family<List<TableMatchResult>, ({String name, String email})>(
        (ref, key) async {
  final tables = await ref.watch(dataTablesProvider.future);
  final results = <TableMatchResult>[];
  final nameL = key.name.toLowerCase();
  final emailL = key.email.toLowerCase();
  final firstNameL = nameL.split(' ').first;

  for (final t in tables) {
    if (t.columns.isEmpty || t.rows.isEmpty) continue;
    final matched = <List<String>>[];
    for (final row in t.rows) {
      final hay = row.join(' ').toLowerCase();
      if (hay.contains(nameL) || hay.contains(emailL) || hay.contains(firstNameL)) {
        matched.add(row);
      }
    }
    if (matched.isNotEmpty) {
      results.add((
        tableName: t.name,
        tableId: t.id,
        columns: t.columns,
        matchingRows: matched,
      ));
    }
  }
  return results;
});
