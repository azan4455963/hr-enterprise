import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid_plus/pluto_grid_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_table_providers.dart';
import '../../../providers/service_providers.dart';

/// Excel-style editor (PlutoGrid): inline cell editing, keyboard navigation,
/// bulk add rows, paste, rename/delete columns, delete rows, colour-coded.
class DataTableEditorScreen extends ConsumerStatefulWidget {
  const DataTableEditorScreen({super.key, required this.tableId});
  final String tableId;

  @override
  ConsumerState<DataTableEditorScreen> createState() =>
      _DataTableEditorScreenState();
}

class _DataTableEditorScreenState extends ConsumerState<DataTableEditorScreen> {
  List<String> _columns = [];
  List<List<String>> _rows = [];
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;
  int _structureKey = 0;
  String _tableName = 'Table';
  PlutoGridStateManager? _sm;

  String _field(int i) => 'c$i';

  /// Pull the grid's current values back into [_rows] (reflects edits + sort).
  void _syncFromGrid() {
    final sm = _sm;
    if (sm == null) return;
    _rows = [
      for (final row in sm.rows)
        [
          for (var i = 0; i < _columns.length; i++)
            row.cells[_field(i)]?.value?.toString() ?? '',
        ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(dataTableProvider(widget.tableId));

    return tableAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (table) {
        if (table == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Table not found')),
          );
        }
        if (!_loaded) {
          _columns = [...table.columns];
          _rows = table.rows.map((r) => [...r]).toList();
          _tableName = table.name;
          _loaded = true;
        }

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.heading,
              ),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/tables'),
            ),
            title: GestureDetector(
              onTap: _renameTable,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tableName,
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            actions: [
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              _toolbar(),
              const Divider(height: 1, color: AppColors.cardBorder),
              Expanded(
                child: _columns.isEmpty
                    ? _emptyState()
                    : Padding(padding: const EdgeInsets.all(8), child: _grid()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GhostButton(
            label: 'Add Column',
            icon: Icons.view_column_outlined,
            onPressed: _addColumn,
          ),
          GhostButton(
            label: 'Edit Columns',
            icon: Icons.edit_note_rounded,
            onPressed: _columns.isEmpty ? () {} : _editColumns,
          ),
          GhostButton(
            label: 'Add Row',
            icon: Icons.table_rows_outlined,
            onPressed: _columns.isEmpty ? () {} : () => _addRows(1),
          ),
          GhostButton(
            label: 'Add 10 Rows',
            icon: Icons.playlist_add_rounded,
            onPressed: _columns.isEmpty ? () {} : () => _addRows(10),
          ),
          GhostButton(
            label: 'Select All',
            icon: Icons.select_all_rounded,
            onPressed: _columns.isEmpty ? () {} : _selectAll,
          ),
          GhostButton(
            label: 'Paste',
            icon: Icons.content_paste_rounded,
            onPressed: _pasteFromClipboard,
          ),
          GhostButton(
            label: 'Export PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPressed: _columns.isEmpty ? () {} : _exportPdf,
          ),
          GhostButton(
            label: 'Copy CSV',
            icon: Icons.copy_all_rounded,
            onPressed: _columns.isEmpty ? () {} : _copyCsv,
          ),
          const SizedBox(width: 4),
          Text(
            '${_rows.length} rows · ${_columns.length} cols',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.grid_on_rounded,
            size: 56,
            color: AppColors.textFaint,
          ),
          const SizedBox(height: 10),
          const Text(
            'Empty table',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add columns, or paste data from Excel/Google Sheets',
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Add Column',
            icon: Icons.add,
            onPressed: _addColumn,
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    final columns = <PlutoColumn>[
      // Row-number + delete column (Excel-style row header).
      PlutoColumn(
        title: '#',
        field: 'actions',
        type: PlutoColumnType.text(),
        width: 64,
        frozen: PlutoColumnFrozen.start,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
        backgroundColor: const Color(0xFFF1F5F9),
        renderer: (ctx) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${ctx.rowIdx + 1}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            InkWell(
              onTap: () => _confirmDeleteRow(ctx),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
      for (var i = 0; i < _columns.length; i++)
        PlutoColumn(
          title: _columns[i],
          field: _field(i),
          type: PlutoColumnType.text(),
          width: 150,
          enableColumnDrag: false,
          enableRowDrag: false,
          enableContextMenu: true,
          enableSorting: false,
          enableDropToResize: true,
          renderer: _statusRenderer,
        ),
    ];
    final rows = <PlutoRow>[
      for (final r in _rows)
        PlutoRow(
          cells: {
            'actions': PlutoCell(value: ''),
            for (var i = 0; i < _columns.length; i++)
              _field(i): PlutoCell(value: i < r.length ? r[i] : ''),
          },
        ),
    ];

    return PlutoGrid(
      key: ValueKey('grid_$_structureKey'),
      columns: columns,
      rows: rows,
      columnMenuDelegate: _RenameColumnMenuDelegate(
        columns: _columns,
        onRename: _renameColumnByTitle,
      ),
      onLoaded: (e) {
        _sm = e.stateManager;
        e.stateManager.setSelectingMode(PlutoGridSelectingMode.cell);
      },
      onChanged: (e) {
        if (!_dirty) setState(() => _dirty = true);
      },
      configuration: PlutoGridConfiguration(
        columnSize: const PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.none,
        ),
        style: PlutoGridStyleConfig(
          gridBackgroundColor: Colors.white,
          rowColor: Colors.white,
          oddRowColor: const Color(0xFFF8FAFC),
          activatedColor: AppColors.brandBlueSoft,
          gridBorderColor: AppColors.cardBorder,
          borderColor: AppColors.cardBorder,
          columnTextStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.heading,
          ),
          cellTextStyle: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textBody,
          ),
          columnHeight: 40,
          rowHeight: 38,
          enableColumnBorderVertical: true,
          enableCellBorderVertical: true,
          enableCellBorderHorizontal: true,
          gridBorderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _statusRenderer(PlutoColumnRendererContext ctx) {
    final v = ctx.cell.value?.toString() ?? '';
    final sc = _statusColor(v);
    if (sc == null) return Text(v, overflow: TextOverflow.ellipsis);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: sc.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        v,
        style: TextStyle(color: sc.fg, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Finds the index of a column by name (case-insensitive).
  int _columnIndex(String name) =>
      _columns.indexWhere((c) => c.trim().toLowerCase() == name.toLowerCase());

  /// Returns today's day name (e.g., "Monday"), date (e.g., "22-Jun-2026"),
  /// and time (e.g., "14:30").
  (String day, String date, String time) _now() {
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    final date = DateFormat('dd-MMM-yyyy').format(now);
    final time = DateFormat('HH:mm').format(now);
    return (day, date, time);
  }

  /// Auto-fills the "Day", "Date", and "Time" columns in the given row if
  /// those columns exist.
  void _fillDayDateTime(List<String> row) {
    final dayIdx = _columnIndex('day');
    final dateIdx = _columnIndex('date');
    final timeIdx = _columnIndex('time');
    if (dayIdx < 0 && dateIdx < 0 && timeIdx < 0) return;
    final (day, date, time) = _now();
    if (dayIdx >= 0 && dayIdx < row.length && row[dayIdx].isEmpty) {
      row[dayIdx] = day;
    }
    if (dateIdx >= 0 && dateIdx < row.length && row[dateIdx].isEmpty) {
      row[dateIdx] = date;
    }
    if (timeIdx >= 0 && timeIdx < row.length && row[timeIdx].isEmpty) {
      row[timeIdx] = time;
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────────

  /// Rename the table itself (tapping the AppBar title).
  Future<void> _renameTable() async {
    final name = await _prompt('Rename Table', initial: _tableName);
    if (name == null || name.trim().isEmpty) return;
    final newName = name.trim();
    setState(() {
      _tableName = newName;
      _dirty = true;
    });
  }

  /// Called by [_RenameColumnMenuDelegate] with the column's current title.
  Future<void> _renameColumnByTitle(String currentTitle) async {
    final idx = _columns.indexOf(currentTitle);
    if (idx < 0) return;
    final name = await _prompt('Rename Column', initial: currentTitle);
    if (name == null || name.trim().isEmpty) return;
    _syncFromGrid();
    setState(() {
      _columns[idx] = name.trim();
      _dirty = true;
      _structureKey++;
    });
  }

  /// Show Yes/No confirmation before removing a row.
  Future<void> _confirmDeleteRow(PlutoColumnRendererContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Row',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('Remove row ${ctx.rowIdx + 1}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ctx.stateManager.removeRows([ctx.row]);
    setState(() => _dirty = true);
  }

  /// Select all cells in the grid (Ctrl+C then copies the selection).
  void _selectAll() {
    final sm = _sm;
    if (sm == null || sm.rows.isEmpty) return;
    sm.setAllCurrentSelecting();
  }

  Future<void> _addColumn() async {
    final name = await _prompt('New column name', hint: 'e.g. Name / Date');
    if (name == null || name.trim().isEmpty) return;
    _syncFromGrid();
    setState(() {
      _columns.add(name.trim());
      for (final row in _rows) {
        row.add('');
      }
      if (_rows.isEmpty) _rows.add(List<String>.filled(_columns.length, ''));
      _dirty = true;
      _structureKey++;
    });
  }

  /// Rename / delete / reorder columns via a dialog.
  Future<void> _editColumns() async {
    final result = await showDialog<List<({int idx, String name})>>(
      context: context,
      builder: (_) => _EditColumnsDialog(columns: _columns),
    );
    if (result == null) return;
    _syncFromGrid();
    setState(() {
      final newCols = result.map((e) => e.name).toList();
      final newRows = _rows
          .map(
            (r) => result
                .map((e) => e.idx >= 0 && e.idx < r.length ? r[e.idx] : '')
                .toList(),
          )
          .toList();
      _columns = newCols;
      _rows = newRows;
      _dirty = true;
      _structureKey++;
    });
  }

  void _addRows(int n) {
    _syncFromGrid();
    setState(() {
      for (var i = 0; i < n; i++) {
        final row = List<String>.filled(_columns.length, '');
        _fillDayDateTime(row);
        _rows.add(row);
      }
      _dirty = true;
      _structureKey++;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      _snack('Clipboard is empty. Copy cells from Excel/Sheets first.');
      return;
    }
    final lines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    final parsed = lines.map((l) => l.split('\t')).toList();
    _syncFromGrid();
    setState(() {
      if (_columns.isEmpty) {
        _columns = parsed.first.map((c) => c.trim()).toList();
        _rows = parsed.skip(1).map((r) {
          final row = List<String>.filled(_columns.length, '');
          for (var i = 0; i < r.length && i < _columns.length; i++) {
            row[i] = r[i].trim();
          }
          return row;
        }).toList();
      } else {
        for (final r in parsed) {
          final row = List<String>.filled(_columns.length, '');
          for (var i = 0; i < r.length && i < _columns.length; i++) {
            row[i] = r[i].trim();
          }
          _rows.add(row);
        }
      }
      _dirty = true;
      _structureKey++;
    });
    _snack('Pasted ${parsed.length} line(s).');
  }

  Future<void> _save() async {
    _syncFromGrid();
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      await ref
          .read(dataTableServiceProvider)
          .save(
            widget.tableId,
            name: _tableName,
            columns: _columns,
            rows: _rows,
            userId: user?.id ?? '',
          );
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    _syncFromGrid();
    try {
      await ref
          .read(exportServiceProvider)
          .shareTablePdf(title: _tableName, columns: _columns, rows: _rows);
    } catch (e) {
      _snack('Export failed: $e');
    }
  }

  void _copyCsv() {
    _syncFromGrid();
    String esc(String v) =>
        v.contains(',') || v.contains('"') || v.contains('\n')
        ? '"${v.replaceAll('"', '""')}"'
        : v;
    final buf = StringBuffer()..writeln(_columns.map(esc).join(','));
    for (final r in _rows) {
      buf.writeln(
        [
          for (var i = 0; i < _columns.length; i++)
            esc(i < r.length ? r[i] : ''),
        ].join(','),
      );
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Copied as CSV — paste into Excel/Sheets.');
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<String?> _prompt(String title, {String initial = '', String? hint}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'OK',
            onPressed: () => Navigator.pop(ctx, c.text),
          ),
        ],
      ),
    );
  }
}

({Color bg, Color fg})? _statusColor(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty || v == '-') return null;
  if (v.contains('leave') || v.contains('vacation')) {
    return (bg: AppColors.pillBlueBg, fg: AppColors.pillBlueFg);
  }
  if (v.contains('absent') || v.contains('terminate')) {
    return (bg: AppColors.pillRedBg, fg: AppColors.pillRedFg);
  }
  if (v.contains('late')) {
    return (bg: AppColors.pillAmberBg, fg: AppColors.pillAmberFg);
  }
  if (v.contains('present') || v.contains('hour')) {
    return (bg: AppColors.pillGreenBg, fg: AppColors.pillGreenFg);
  }
  return null;
}

// ── Custom column context-menu with Rename ─────────────────────────────────

enum _ColumnMenuItem { rename, autoFit, freezeStart, freezeEnd, unfreeze }

/// Replaces PlutoGrid's default column menu, adding a "Rename Column" entry.
class _RenameColumnMenuDelegate
    implements PlutoColumnMenuDelegate<_ColumnMenuItem> {
  const _RenameColumnMenuDelegate({
    required this.columns,
    required this.onRename,
  });

  final List<String> columns;
  final void Function(String columnTitle) onRename;

  @override
  List<PopupMenuEntry<_ColumnMenuItem>> buildMenuItems({
    required PlutoGridStateManager stateManager,
    required PlutoColumn column,
  }) {
    // Only show Rename for user-defined columns (not the # column).
    final isDataColumn = columns.contains(column.title);
    return [
      if (isDataColumn) ...[
        const PopupMenuItem<_ColumnMenuItem>(
          value: _ColumnMenuItem.rename,
          height: 36,
          child: Row(
            children: [
              Icon(Icons.drive_file_rename_outline_rounded, size: 16),
              SizedBox(width: 8),
              Text('Rename Column', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],
      const PopupMenuItem<_ColumnMenuItem>(
        value: _ColumnMenuItem.autoFit,
        height: 36,
        child: Text('Auto-fit width', style: TextStyle(fontSize: 13)),
      ),
      if (column.frozen.isFrozen)
        const PopupMenuItem<_ColumnMenuItem>(
          value: _ColumnMenuItem.unfreeze,
          height: 36,
          child: Text('Unfreeze', style: TextStyle(fontSize: 13)),
        )
      else ...[
        const PopupMenuItem<_ColumnMenuItem>(
          value: _ColumnMenuItem.freezeStart,
          height: 36,
          child: Text('Freeze left', style: TextStyle(fontSize: 13)),
        ),
        const PopupMenuItem<_ColumnMenuItem>(
          value: _ColumnMenuItem.freezeEnd,
          height: 36,
          child: Text('Freeze right', style: TextStyle(fontSize: 13)),
        ),
      ],
    ];
  }

  @override
  void onSelected({
    required BuildContext context,
    required PlutoGridStateManager stateManager,
    required PlutoColumn column,
    required bool mounted,
    required _ColumnMenuItem? selected,
  }) {
    switch (selected) {
      case _ColumnMenuItem.rename:
        onRename(column.title);
        break;
      case _ColumnMenuItem.autoFit:
        if (!mounted) return;
        stateManager.autoFitColumn(context, column);
        stateManager.notifyResizingListeners();
        break;
      case _ColumnMenuItem.freezeStart:
        stateManager.toggleFrozenColumn(column, PlutoColumnFrozen.start);
        break;
      case _ColumnMenuItem.freezeEnd:
        stateManager.toggleFrozenColumn(column, PlutoColumnFrozen.end);
        break;
      case _ColumnMenuItem.unfreeze:
        stateManager.toggleFrozenColumn(column, PlutoColumnFrozen.none);
        break;
      case null:
        break;
    }
  }
}

/// Dialog to rename / delete columns. Returns the kept columns as
/// (original index, new name), preserving order.
class _EditColumnsDialog extends StatefulWidget {
  const _EditColumnsDialog({required this.columns});
  final List<String> columns;

  @override
  State<_EditColumnsDialog> createState() => _EditColumnsDialogState();
}

class _EditColumnsDialogState extends State<_EditColumnsDialog> {
  late final List<({int idx, TextEditingController c})> _items = [
    for (var i = 0; i < widget.columns.length; i++)
      (idx: i, c: TextEditingController(text: widget.columns[i])),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Edit Columns',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: _items.isEmpty
            ? const Text('No columns left. Add one after closing.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _items[i].c,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Column',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            tooltip: 'Delete column',
                            onPressed: () => setState(() => _items.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Save',
          onPressed: () {
            final result = [
              for (final it in _items)
                (
                  idx: it.idx,
                  name: it.c.text.trim().isEmpty ? 'Column' : it.c.text.trim(),
                ),
            ];
            Navigator.pop(context, result);
          },
        ),
      ],
    );
  }
}
