import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/data_table_model.dart';
import '../services/data_table_service.dart';

final dataTableServiceProvider = Provider<DataTableService>((ref) {
  return DataTableService();
});

/// All custom tables (newest first).
final dataTablesProvider = StreamProvider<List<DataTableModel>>((ref) {
  return ref.watch(dataTableServiceProvider).watchTables();
});

/// A single table, live.
final dataTableProvider =
    StreamProvider.family<DataTableModel?, String>((ref, id) {
  return ref.watch(dataTableServiceProvider).watchTable(id);
});
