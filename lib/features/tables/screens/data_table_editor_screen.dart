import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid_plus/pluto_grid_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/export_menu.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/data_table_model.dart';
import '../../../models/employee_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
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
  // All tabs/sheets in the workbook; the active one is mirrored into
  // [_columns]/[_rows] for the grid.
  List<DataSheet> _sheets = [];
  int _active = 0;
  List<String> _columns = [];
  List<List<String>> _rows = [];
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;
  int _structureKey = 0;
  String _tableName = 'Table';
  PlutoGridStateManager? _sm;
  Timer? _autoSave;
  bool _showTotals = false;
  // Attendance highlighting: which columns are employees (not Date/Day) and
  // whether this looks like an attendance table (has a Date column).
  bool _isAttendance = false;
  Set<int> _employeeCols = {};
  // Excel-style row selection (click #, Ctrl/Shift) for bulk delete.
  final Set<int> _selectedRows = {};
  int? _selectAnchor;
  // View-only filter. While a filter is active the grid is READ-ONLY and
  // [_syncFromGrid] is skipped, so the save path is never fed a filtered
  // subset of rows (which would otherwise delete the hidden rows).
  final TextEditingController _filterCtrl = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    // Auto-save: every 3s, if there are unsaved changes, persist them.
    _autoSave = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_loaded && _dirty && !_saving) _save();
    });
  }

  @override
  void dispose() {
    _autoSave?.cancel();
    _filterCtrl.dispose();
    super.dispose();
  }

  String _field(int i) => 'c$i';

  /// Write the grid's current values back into the active sheet.
  void _commitActive() {
    _syncFromGrid();
    if (_active >= 0 && _active < _sheets.length) {
      _sheets[_active] = _sheets[_active].copyWith(
        columns: [..._columns],
        rows: [for (final r in _rows) [...r]],
      );
    }
  }

  void _loadSheet(int i) {
    if (i < 0 || i >= _sheets.length) return;
    _active = i;
    _columns = [..._sheets[i].columns];
    _rows = _sheets[i].rows.map((r) => [...r]).toList();
    _selectedRows.clear();
    _selectAnchor = null;
    _filter = '';
    _filterCtrl.clear();
    if (_autoMapDays()) _dirty = true;
    _structureKey++;
  }

  void _switchSheet(int i) {
    if (i == _active) return;
    setState(() {
      _commitActive();
      _loadSheet(i);
    });
  }

  /// Pull the grid's current values back into [_rows] (reflects edits).
  /// IMPORTANT: never runs while a filter is active — the grid then shows only
  /// a subset of rows, so reading it back would drop the hidden ones.
  void _syncFromGrid() {
    if (_filter.trim().isNotEmpty) return;
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
          _sheets = table.sheets.isNotEmpty
              ? [...table.sheets]
              : [const DataSheet(name: 'Sheet 1')];
          _active = 0;
          _columns = [..._sheets[0].columns];
          _rows = _sheets[0].rows.map((r) => [...r]).toList();
          _tableName = table.name;
          if (_autoMapDays()) _dirty = true;
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
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(child: _saveStatus()),
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
              const Divider(height: 1, color: AppColors.cardBorder),
              _sheetTabsBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    final filterActive = _filter.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Editing tools are hidden while filtering (the filtered view is
          // read-only) so a partial view can never be saved.
          if (!filterActive) ...[
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
              label: 'Fill Dates',
              icon: Icons.event_note_rounded,
              onPressed: _columns.isEmpty ? () {} : _fillMonthDates,
            ),
            GhostButton(
              label: 'Sort',
              icon: Icons.swap_vert_rounded,
              onPressed: _columns.isEmpty ? () {} : _showSortDialog,
            ),
            GhostButton(
              label: _showTotals ? 'Hide Totals' : 'Totals',
              icon: Icons.functions_rounded,
              onPressed: _columns.isEmpty
                  ? () {}
                  : () => setState(() {
                        _showTotals = !_showTotals;
                        _structureKey++;
                      }),
            ),
            GhostButton(
              label: 'Select All',
              icon: Icons.select_all_rounded,
              onPressed: _columns.isEmpty ? () {} : _selectAll,
            ),
            if (_selectedRows.isNotEmpty)
              PrimaryButton(
                label: 'Delete ${_selectedRows.length} row'
                    '${_selectedRows.length == 1 ? "" : "s"}',
                icon: Icons.delete_outline_rounded,
                color: AppColors.error,
                onPressed: _deleteSelectedRows,
              ),
            GhostButton(
              label: 'Paste',
              icon: Icons.content_paste_rounded,
              onPressed: _pasteFromClipboard,
            ),
            if (_isSalaryTable)
              GhostButton(
                label: 'Sync salaries',
                icon: Icons.sync_rounded,
                onPressed: _syncSalaries,
              ),
            GhostButton(
              label: 'Export PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: _columns.isEmpty ? () {} : _exportPdf,
            ),
            GhostButton(
              label: 'Export Excel',
              icon: Icons.table_chart_outlined,
              onPressed: _columns.isEmpty ? () {} : _exportExcel,
            ),
            GhostButton(
              label: 'Copy CSV',
              icon: Icons.copy_all_rounded,
              onPressed: _columns.isEmpty ? () {} : _copyCsv,
            ),
          ],
          _searchField(),
          if (filterActive)
            const Text(
              'Filtered — read-only. Clear to edit.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600),
            ),
          const SizedBox(width: 4),
          Text(
            filterActive
                ? '${_matchCount()} of ${_rows.length} rows'
                : '${_rows.length} rows · ${_columns.length} cols',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      width: 210,
      height: 34,
      child: TextField(
        controller: _filterCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Filter rows…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 16),
          suffixIcon: _filter.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  splashRadius: 16,
                  onPressed: _clearFilter,
                ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (v) {
          // Capture any pending grid edit BEFORE the view filters (the guard in
          // _syncFromGrid only blocks once _filter is already set), so editing a
          // cell then immediately filtering never loses that edit.
          _syncFromGrid();
          setState(() {
            _filter = v;
            _selectedRows.clear();
            _selectAnchor = null;
            _structureKey++;
          });
        },
      ),
    );
  }

  void _clearFilter() {
    setState(() {
      _filter = '';
      _filterCtrl.clear();
      _structureKey++;
    });
  }

  bool _matchesFilter(List<String> row, String q) =>
      row.any((c) => c.toLowerCase().contains(q));

  int _matchCount() {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _rows.length;
    return _rows.where((r) => _matchesFilter(r, q)).length;
  }

  // ── Sort (explicit; reorders whole rows — only order changes, never data) ──
  Future<void> _showSortDialog() async {
    if (_columns.isEmpty) return;
    var col = 0;
    var asc = true;
    final res = await showDialog<({int col, bool asc})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sort rows',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: col,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sort by column'),
                items: [
                  for (var i = 0; i < _columns.length; i++)
                    DropdownMenuItem(value: i, child: Text(_columns[i])),
                ],
                onChanged: (v) => setLocal(() => col = v ?? 0),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Ascending'),
                      selected: asc,
                      onSelected: (_) => setLocal(() => asc = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Descending'),
                      selected: !asc,
                      onSelected: (_) => setLocal(() => asc = false),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            PrimaryButton(
              label: 'Sort',
              onPressed: () => Navigator.pop(ctx, (col: col, asc: asc)),
            ),
          ],
        ),
      ),
    );
    if (res == null) return;
    _sortByColumn(res.col, res.asc);
  }

  /// Reorder [_rows] by a column. Rows move as whole units, so each row keeps
  /// its own cells together — only the order changes, never the data.
  void _sortByColumn(int col, bool asc) {
    _syncFromGrid();
    setState(() {
      _rows.sort((a, b) {
        final av = col < a.length ? a[col] : '';
        final bv = col < b.length ? b[col] : '';
        final cmp = _smartCompare(av, bv);
        return asc ? cmp : -cmp;
      });
      _dirty = true;
      _structureKey++;
    });
    _snack('Sorted by "${_columns[col]}" (${asc ? "A→Z" : "Z→A"}).');
  }

  /// Compare two cell strings: numbers numerically, dates by date, blanks last,
  /// otherwise case-insensitive text.
  int _smartCompare(String a, String b) {
    final at = a.trim(), bt = b.trim();
    if (at.isEmpty && bt.isEmpty) return 0;
    if (at.isEmpty) return 1; // blanks sink to the bottom
    if (bt.isEmpty) return -1;
    final na = num.tryParse(at.replaceAll(',', ''));
    final nb = num.tryParse(bt.replaceAll(',', ''));
    if (na != null && nb != null) return na.compareTo(nb);
    final da = _tryParseDate(at);
    final db = _tryParseDate(bt);
    if (da != null && db != null) return da.compareTo(db);
    return at.toLowerCase().compareTo(bt.toLowerCase());
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

  /// Detect attendance layout (has a Date column) and which columns are
  /// employees (everything except Date / Day / Working Days). Used to grey-out
  /// empty (off/holiday) employee cells.
  void _computeAttendanceMeta() {
    Set<String> wordsOf(String h) =>
        h.trim().toLowerCase().split(RegExp(r'[\s/_\-]+')).toSet();
    bool isDateOrDay(String h) {
      final w = wordsOf(h);
      return w.contains('date') || w.contains('day') || w.contains('days');
    }

    _isAttendance =
        _columns.any((c) => wordsOf(c).contains('date'));
    _employeeCols = {
      for (var i = 0; i < _columns.length; i++)
        if (!isDateOrDay(_columns[i])) i,
    };
  }

  Widget _grid() {
    _computeAttendanceMeta();
    final filterActive = _filter.trim().isNotEmpty;
    final q = _filter.trim().toLowerCase();
    // The rows to display, each tagged with its original index into [_rows] so
    // selection/delete stay correct even when the view is filtered.
    final displayPairs = <({int idx, List<String> row})>[
      for (var i = 0; i < _rows.length; i++)
        if (!filterActive || _matchesFilter(_rows[i], q)) (idx: i, row: _rows[i]),
    ];
    final columns = <PlutoColumn>[
      // Row-number + delete column (Excel-style row header).
      PlutoColumn(
        title: '#',
        field: 'actions',
        type: PlutoColumnType.text(),
        width: 86,
        frozen: PlutoColumnFrozen.start,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
        backgroundColor: const Color(0xFFF1F5F9),
        renderer: (ctx) {
          final origIdx =
              int.tryParse(ctx.cell.value?.toString() ?? '') ?? ctx.rowIdx;
          // While filtering the grid is read-only — just show the row number.
          if (_filter.trim().isNotEmpty) {
            return Center(
              child: Text('${origIdx + 1}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textFaint)),
            );
          }
          final selected = _selectedRows.contains(origIdx);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleRowSelect(origIdx),
            onSecondaryTapDown: (d) {
              if (!_selectedRows.contains(origIdx)) {
                _toggleRowSelect(origIdx, forceSingle: true);
              }
              _rowContextMenu(d.globalPosition);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 15,
                  color: selected ? AppColors.brandBlue : AppColors.textFaint,
                ),
                Text(
                  '${origIdx + 1}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
                InkWell(
                  onTap: () => _confirmDeleteRow(ctx),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.textFaint),
                ),
              ],
            ),
          );
        },
      ),
      for (var i = 0; i < _columns.length; i++)
        PlutoColumn(
          title: _columns[i],
          field: _field(i),
          type: PlutoColumnType.text(),
          width: 150,
          // Drag a column header to reorder it (first / middle / last).
          enableColumnDrag: true,
          enableRowDrag: false,
          enableContextMenu: true,
          enableSorting: false,
          enableEditingMode: !filterActive, // read-only while filtering
          enableDropToResize: true,
          renderer: _statusRenderer,
          footerRenderer: _showTotals ? _columnFooter : null,
        ),
    ];
    final rows = <PlutoRow>[
      for (final p in displayPairs)
        PlutoRow(
          cells: {
            // Carry the original row index so the header renderer can map back.
            'actions': PlutoCell(value: '${p.idx}'),
            for (var i = 0; i < _columns.length; i++)
              _field(i): PlutoCell(value: i < p.row.length ? p.row[i] : ''),
          },
        ),
    ];

    return Focus(
      onKeyEvent: _handleGridKey,
      child: PlutoGrid(
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
      onColumnsMoved: (_) => _applyColumnOrder(),
      onChanged: (e) {
        _onCellChanged(e);
        if (!_dirty) setState(() => _dirty = true);
      },
      rowColorCallback: (ctx) {
        if (_selectedRows.contains(ctx.rowIdx)) {
          return const Color(0xFFDCE7FF); // selected — light blue
        }
        return ctx.rowIdx.isOdd ? const Color(0xFFF8FAFC) : Colors.white;
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
      ),
    );
  }

  /// Delete key removes the selected rows (when not editing a cell).
  KeyEventResult _handleGridKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) &&
        _selectedRows.isNotEmpty &&
        !(_sm?.isEditing ?? false)) {
      _deleteSelectedRows();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _statusRenderer(PlutoColumnRendererContext ctx) {
    final v = ctx.cell.value?.toString() ?? '';
    final t = v.trim();

    // Off / holiday: an empty (or "-") employee cell in an attendance table.
    final field = ctx.column.field;
    final colIdx =
        field.startsWith('c') ? int.tryParse(field.substring(1)) ?? -1 : -1;
    final isEmployeeCell =
        _isAttendance && colIdx >= 0 && _employeeCols.contains(colIdx);
    if (isEmployeeCell &&
        (t.isEmpty || t == '-' || t == '–' || t == '—')) {
      // Off / holiday cell — kept subtle: a faint grey tint with a small dash,
      // so the table stays clean and only marked attendance stands out.
      return Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        color: const Color(0xFFF3F5F8),
        child: const Text('–',
            style: TextStyle(fontSize: 13, color: Color(0xFFB6BECC))),
      );
    }

    final sc = _statusColor(v);
    if (sc == null) {
      // Plain text / numbers — force a dark colour so cells are always
      // readable (the default can render white/invisible).
      return Text(
        v,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textBody,
            fontWeight: FontWeight.w500),
      );
    }
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

  /// Column footer: sum of numeric columns, else count of filled cells.
  Widget _columnFooter(PlutoColumnFooterRendererContext ctx) {
    final field = ctx.column.field;
    num sum = 0;
    var numeric = 0, filled = 0;
    for (final row in ctx.stateManager.refRows) {
      final v = row.cells[field]?.value?.toString().trim() ?? '';
      if (v.isEmpty || v == '-') continue;
      filled++;
      final n = num.tryParse(v.replaceAll(',', ''));
      if (n != null) {
        sum += n;
        numeric++;
      }
    }
    final isNumeric = numeric > 0 && numeric >= filled * 0.5;
    final sumLabel =
        sum % 1 == 0 ? sum.toInt().toString() : sum.toStringAsFixed(2);
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        isNumeric ? 'Σ $sumLabel' : '$filled filled',
        style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.brandNavy),
      ),
    );
  }

  /// Finds the index of a column whose name contains [keyword] as a whole word
  /// (case-insensitive). Splits on spaces, slashes, dashes and underscores, so
  /// "Date", "Current Date", "Date/Time", "Join_Date" all match "date".
  int _dateTimeColumnIndex(String keyword) {
    for (var i = 0; i < _columns.length; i++) {
      final words = _columns[i]
          .trim()
          .toLowerCase()
          .split(RegExp(r'[\s/_\-]+'))
          .where((w) => w.isNotEmpty);
      if (words.contains(keyword)) return i;
    }
    return -1;
  }

  /// Finds the "Day" column — matches "Day", "Days", "Working Day(s)".
  int _dayColumnIndex() {
    for (var i = 0; i < _columns.length; i++) {
      final words = _columns[i]
          .trim()
          .toLowerCase()
          .split(RegExp(r'[\s/_\-]+'))
          .where((w) => w.isNotEmpty);
      if (words.contains('day') || words.contains('days')) return i;
    }
    return -1;
  }

  /// Try to parse a date cell ("01-Jun-2026", "06/01/2026", ISO, …).
  DateTime? _tryParseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    for (final f in const [
      'dd-MMM-yyyy', 'd-MMM-yyyy', 'dd-MM-yyyy',
      'MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd',
    ]) {
      try {
        return DateFormat(f).parseStrict(s);
      } catch (_) {/* next */}
    }
    return DateTime.tryParse(s);
  }

  /// Fill any empty Day cell from its row's Date, so the day name always
  /// matches the date — survives table delete/recreate, paste, etc. Returns
  /// true if anything changed.
  bool _autoMapDays() {
    final dateIdx = _dateTimeColumnIndex('date');
    final dayIdx = _dayColumnIndex();
    if (dateIdx < 0 || dayIdx < 0) return false;
    var changed = false;
    for (final r in _rows) {
      if (dateIdx < r.length &&
          dayIdx < r.length &&
          r[dayIdx].trim().isEmpty) {
        final d = _tryParseDate(r[dateIdx]);
        if (d != null) {
          r[dayIdx] = DateFormat('EEEE').format(d);
          changed = true;
        }
      }
    }
    return changed;
  }

  /// When a Date cell is edited, fill that row's empty Day cell from it.
  void _onCellChanged(PlutoGridOnChangedEvent e) {
    final sm = _sm;
    if (sm == null) return;
    final dateIdx = _dateTimeColumnIndex('date');
    final dayIdx = _dayColumnIndex();
    if (dateIdx < 0 || dayIdx < 0) return;
    if (e.column.field != _field(dateIdx)) return; // only when Date edited
    final d = _tryParseDate(e.value?.toString() ?? '');
    if (d == null) return;
    final dayCell = e.row.cells[_field(dayIdx)];
    if (dayCell == null) return;
    if (dayCell.value?.toString().trim().isEmpty ?? true) {
      sm.changeCellValue(dayCell, DateFormat('EEEE').format(d),
          callOnChangedEvent: false, notify: true);
    }
  }

  /// Auto-fills the Date / Day / Time columns of a new row. The date continues
  /// the sequence (day after the last dated row, else today); the day name and
  /// time match. Only fills empty cells.
  void _fillDayDateTime(List<String> row) {
    final dayIdx = _dayColumnIndex();
    final dateIdx = _dateTimeColumnIndex('date');
    final timeIdx = _dateTimeColumnIndex('time');
    if (dayIdx < 0 && dateIdx < 0 && timeIdx < 0) return;

    // Sequential date: next day after the last filled date, else today.
    var target = DateTime.now();
    if (dateIdx >= 0) {
      DateTime? last;
      for (final r in _rows) {
        if (dateIdx < r.length) {
          final d = _tryParseDate(r[dateIdx]);
          if (d != null) last = d;
        }
      }
      if (last != null) target = last.add(const Duration(days: 1));
    }

    final dayName = DateFormat('EEEE').format(target);
    final dateStr = DateFormat('dd-MMM-yyyy').format(target);
    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    if (dateIdx >= 0 && dateIdx < row.length && row[dateIdx].isEmpty) {
      row[dateIdx] = dateStr;
    }
    if (dayIdx >= 0 && dayIdx < row.length && row[dayIdx].isEmpty) {
      row[dayIdx] = dayName;
    }
    if (timeIdx >= 0 && timeIdx < row.length && row[timeIdx].isEmpty) {
      row[timeIdx] = timeStr;
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

  /// Show a Yes/No confirmation (a popup over the table — it never leaves the
  /// editor) before removing a row.
  Future<void> _confirmDeleteRow(PlutoColumnRendererContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 32),
        title: const Text(
          'Delete this row?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete row ${ctx.rowIdx + 1}? '
          'This cannot be undone.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _syncFromGrid();
    final origIdx =
        int.tryParse(ctx.row.cells['actions']?.value?.toString() ?? '') ??
            ctx.rowIdx;
    setState(() {
      if (origIdx >= 0 && origIdx < _rows.length) _rows.removeAt(origIdx);
      _selectedRows.clear();
      _selectAnchor = null;
      _dirty = true;
      _structureKey++;
    });
    _snack('Row deleted.');
  }

  /// Select all cells in the grid (Ctrl+C then copies the selection).
  void _selectAll() {
    final sm = _sm;
    if (sm == null || sm.rows.isEmpty) return;
    sm.setAllCurrentSelecting();
  }

  // ── Excel-style row selection + bulk delete ─────────────────────────────
  /// Toggle/extend the row selection (respects Ctrl/Cmd toggle, Shift range).
  void _toggleRowSelect(int idx, {bool forceSingle = false}) {
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      if (!forceSingle && shift && _selectAnchor != null) {
        final a = _selectAnchor!;
        final lo = a < idx ? a : idx;
        final hi = a < idx ? idx : a;
        for (var i = lo; i <= hi; i++) {
          _selectedRows.add(i);
        }
      } else if (!forceSingle && ctrl) {
        if (!_selectedRows.remove(idx)) _selectedRows.add(idx);
        _selectAnchor = idx;
      } else {
        if (_selectedRows.length == 1 && _selectedRows.contains(idx)) {
          _selectedRows.clear();
        } else {
          _selectedRows
            ..clear()
            ..add(idx);
        }
        _selectAnchor = idx;
      }
    });
  }

  Future<void> _rowContextMenu(Offset pos) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            const SizedBox(width: 10),
            Text('Delete ${_selectedRows.length} row'
                '${_selectedRows.length == 1 ? "" : "s"}'),
          ]),
        ),
      ],
    );
    if (action == 'delete') _deleteSelectedRows();
  }

  /// Delete all currently-selected rows at once (with confirmation).
  Future<void> _deleteSelectedRows() async {
    if (_selectedRows.isEmpty) return;
    final n = _selectedRows.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 32),
        title: const Text('Delete rows',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Delete $n selected row${n == 1 ? "" : "s"}? '
            'This cannot be undone.'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text('Yes, delete $n'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _syncFromGrid();
    setState(() {
      final keep = <List<String>>[];
      for (var i = 0; i < _rows.length; i++) {
        if (!_selectedRows.contains(i)) keep.add(_rows[i]);
      }
      _rows = keep;
      _selectedRows.clear();
      _selectAnchor = null;
      _dirty = true;
      _structureKey++;
    });
    _snack('$n row${n == 1 ? "" : "s"} deleted.');
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
      if (_rows.isEmpty) {
        final row = List<String>.filled(_columns.length, '');
        _fillDayDateTime(row);
        _rows.add(row);
      }
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

  static const _monthNumbers = {
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5,
    'june': 6, 'july': 7, 'august': 8, 'september': 9, 'october': 10,
    'november': 11, 'december': 12,
  };

  /// Fill the active tab's "Date" + "Working Days" columns with every date of
  /// the month (detected from the tab name, else current month). Adds rows as
  /// needed and preserves other columns' values. One-click for any tab.
  Future<void> _fillMonthDates() async {
    int dateIdx = -1, dayIdx = -1;
    for (var i = 0; i < _columns.length; i++) {
      final h = _columns[i].trim().toLowerCase();
      if (dateIdx < 0 && h == 'date') dateIdx = i;
      if (dayIdx < 0 &&
          (h == 'working days' || h == 'day' || h == 'days' || h == 'working day')) {
        dayIdx = i;
      }
    }
    if (dateIdx < 0) {
      _snack('No "Date" column found. Add a column named "Date" first '
          '(or create an Attendance workbook).');
      return;
    }

    // Month from tab name, else current month.
    final tabName = _sheets.isNotEmpty && _active < _sheets.length
        ? _sheets[_active].name.trim().toLowerCase()
        : '';
    final now = DateTime.now();
    int month = now.month;
    _monthNumbers.forEach((k, v) {
      if (tabName.contains(k)) month = v;
    });

    final yearStr = await _prompt('Fill dates — which year?',
        initial: '${now.year}', hint: 'e.g. ${now.year}');
    if (yearStr == null) return;
    final year = int.tryParse(yearStr.trim()) ?? now.year;

    final days = DateTime(year, month + 1, 0).day;
    final dateFmt = DateFormat('dd-MMM-yyyy');
    final dayFmt = DateFormat('EEEE');
    _syncFromGrid();
    setState(() {
      for (var d = 1; d <= days; d++) {
        if (d - 1 >= _rows.length) {
          _rows.add(List<String>.filled(_columns.length, ''));
        }
        final row = _rows[d - 1];
        while (row.length < _columns.length) {
          row.add('');
        }
        final date = DateTime(year, month, d);
        row[dateIdx] = dateFmt.format(date);
        if (dayIdx >= 0) row[dayIdx] = dayFmt.format(date);
      }
      _dirty = true;
      _structureKey++;
    });
    _snack('Filled $days dates. Press Save to keep them.');
  }

  /// After a column header is dragged, persist the new visual order into
  /// [_columns] and [_rows] so it survives a rebuild and is saved.
  void _applyColumnOrder() {
    final sm = _sm;
    if (sm == null) return;
    _syncFromGrid(); // capture edits in the current order first

    // New data-column order (skip the frozen '#'/actions column). Each field
    // is 'cN' where N is the index into the *current* _columns list.
    final newOrder = <int>[
      for (final col in sm.columns)
        if (col.field != 'actions') int.parse(col.field.substring(1)),
    ];
    // Guard against anything unexpected.
    if (newOrder.length != _columns.length) return;

    setState(() {
      _columns = [for (final i in newOrder) _columns[i]];
      _rows = [
        for (final r in _rows)
          [for (final i in newOrder) (i < r.length ? r[i] : '')],
      ];
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
      _autoMapDays();
      _dirty = true;
      _structureKey++;
    });
    _snack('Pasted ${parsed.length} line(s).');
  }

  Future<void> _save() async {
    _commitActive();
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      await ref.read(dataTableServiceProvider).save(
            widget.tableId,
            name: _tableName,
            sheets: _sheets,
            userId: user?.id ?? '',
          );
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// AppBar auto-save status (replaces the manual Save button).
  Widget _saveStatus() {
    if (_saving) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Saving…',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
      ]);
    }
    if (_dirty) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_upload_outlined, size: 16, color: AppColors.textMuted),
        SizedBox(width: 6),
        Text('Saving soon…',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
      ]);
    }
    return const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_done_outlined, size: 16, color: AppColors.pillGreenFg),
      SizedBox(width: 6),
      Text('Saved',
          style: TextStyle(fontSize: 12.5, color: AppColors.pillGreenFg)),
    ]);
  }

  // ── Sheet tabs (footer, like Google Sheets) ─────────────────────────────
  Widget _sheetTabsBar() {
    return Container(
      height: 42,
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: _sheets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final active = i == _active;
                return InkWell(
                  onTap: () => _switchSheet(i),
                  onLongPress: () => _sheetMenu(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.brandNavy : AppColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: active
                              ? AppColors.brandNavy
                              : AppColors.cardBorder),
                    ),
                    child: Text(
                      _sheets[i].name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppColors.textBody,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Add tab',
            icon: const Icon(Icons.add, size: 20, color: AppColors.brandNavy),
            onPressed: _addSheet,
          ),
          IconButton(
            tooltip: 'Tab options (rename / delete)',
            icon: const Icon(Icons.more_vert,
                size: 20, color: AppColors.textMuted),
            onPressed: () => _sheetMenu(_active),
          ),
        ],
      ),
    );
  }

  Future<void> _sheetMenu(int i) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Rename "${_sheets[i].name}"'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete tab'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') _renameSheet(i);
    if (action == 'delete') _deleteSheet(i);
  }

  Future<void> _addSheet() async {
    final name = await _prompt('New tab name', hint: 'e.g. July');
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      _commitActive();
      // New tab inherits the current tab's columns (handy for monthly
      // attendance where the employee columns repeat), with no rows.
      final cols = _columns.isNotEmpty ? [..._columns] : <String>['Column 1'];
      _sheets.add(DataSheet(name: name.trim(), columns: cols, rows: const []));
      _loadSheet(_sheets.length - 1);
      _dirty = true;
    });
  }

  Future<void> _renameSheet(int i) async {
    final name = await _prompt('Rename tab', initial: _sheets[i].name);
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      _sheets[i] = _sheets[i].copyWith(name: name.trim());
      _dirty = true;
    });
  }

  Future<void> _deleteSheet(int i) async {
    if (_sheets.length <= 1) {
      _snack('A table needs at least one tab.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete tab',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Delete "${_sheets[i].name}" and all its rows?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _commitActive();
      _sheets.removeAt(i);
      if (_active > i) _active--;
      if (_active >= _sheets.length) _active = _sheets.length - 1;
      _loadSheet(_active);
      _dirty = true;
    });
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

  /// Export the active tab as its own .xlsx file.
  Future<void> _exportExcel() async {
    _syncFromGrid();
    try {
      final sheetName = (_active >= 0 && _active < _sheets.length)
          ? _sheets[_active].name
          : 'Sheet1';
      final bytes = await ref.read(exportServiceProvider).buildSheetExcel(
            sheetName: sheetName,
            columns: _columns,
            rows: _rows,
          );
      String safe(String s) {
        final v = s.trim().replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '_').trim();
        return v.isEmpty ? 'table' : v;
      }

      await saveXlsxBytes(bytes, '${safe(_tableName)}_${safe(sheetName)}.xlsx');
      _snack('Exported "$sheetName" to Excel.');
    } catch (e) {
      _snack('Export failed: $e');
    }
  }

  /// A salary workbook has at least one column mentioning "salary".
  bool get _isSalaryTable =>
      _sheets.any((s) => s.columns.any((c) => c.toLowerCase().contains('salary')));

  double? _parseMoney(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Match a row to one employee by Email → Employee ID / CNIC → Name (in that
  /// order). A name is only used when it matches exactly one person, so
  /// duplicate names never update the wrong record.
  EmployeeModel? _matchEmployee(
    List<EmployeeModel> emps, {
    required String email,
    required String idOrCnic,
    required String name,
  }) {
    final e = email.trim().toLowerCase();
    if (e.isNotEmpty) {
      for (final emp in emps) {
        if (emp.email.trim().toLowerCase() == e) return emp;
      }
    }
    final v = idOrCnic.trim().toLowerCase();
    if (v.isNotEmpty) {
      for (final emp in emps) {
        if (emp.id.toLowerCase() == v || (emp.cnic ?? '').toLowerCase() == v) {
          return emp;
        }
      }
    }
    final n = name.trim().toLowerCase();
    if (n.isNotEmpty) {
      final matches =
          emps.where((emp) => emp.fullName.trim().toLowerCase() == n).toList();
      if (matches.length == 1) return matches.first;
    }
    return null;
  }

  /// Push the "Basic Salary" values from this workbook onto matching employee
  /// records (only when the salary actually changed).
  Future<void> _syncSalaries() async {
    _syncFromGrid();
    final employees =
        ref.read(employeesProvider).valueOrNull ?? const <EmployeeModel>[];
    if (employees.isEmpty) {
      _snack('No employees to match against.');
      return;
    }
    final adminId = ref.read(currentUserProvider).valueOrNull?.id ?? '';
    final svc = ref.read(employeeServiceProvider);
    var updated = 0, unmatched = 0;

    for (final sheet in _sheets) {
      final cols = sheet.columns;
      int idxWhere(bool Function(String) test) =>
          cols.indexWhere((c) => test(c.trim().toLowerCase()));

      var salaryIdx =
          idxWhere((l) => l.contains('basic') && l.contains('salary'));
      if (salaryIdx < 0) salaryIdx = idxWhere((l) => l == 'salary');
      if (salaryIdx < 0) continue;

      final emailIdx = idxWhere((l) => l.contains('email'));
      final idIdx = idxWhere((l) =>
          l.contains('employee id') ||
          l == 'id' ||
          l == 'emp id' ||
          l.contains('cnic'));
      final nameIdx = idxWhere((l) => l.contains('name'));

      for (final row in sheet.rows) {
        String cell(int i) => (i >= 0 && i < row.length) ? row[i] : '';
        final salary = _parseMoney(cell(salaryIdx));
        if (salary == null || salary <= 0) continue;
        final emp = _matchEmployee(
          employees,
          email: cell(emailIdx),
          idOrCnic: cell(idIdx),
          name: cell(nameIdx),
        );
        if (emp == null) {
          unmatched++;
          continue;
        }
        if ((emp.salary ?? -1) != salary) {
          try {
            await svc.updateEmployment(emp.id, salary: salary, userId: adminId);
            updated++;
          } catch (_) {/* skip one, keep going */}
        }
      }
    }
    _snack('Salary sync — $updated updated'
        '${unmatched > 0 ? ', $unmatched row(s) unmatched' : ''}.');
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
