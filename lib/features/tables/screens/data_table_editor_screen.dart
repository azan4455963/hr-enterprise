import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pluto_grid_plus/pluto_grid_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_table_providers.dart';

/// Excel-style editor (PlutoGrid): inline cell editing, keyboard navigation,
/// bulk add rows, paste from a spreadsheet, and colour-coded status cells.
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
  int _structureKey = 0; // bump to rebuild the grid when columns/rows change

  String _field(int i) => 'c$i';

  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(dataTableProvider(widget.tableId));

    return tableAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
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
          _loaded = true;
        }

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.heading),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/tables'),
            ),
            title: Text(table.name,
                style: const TextStyle(
                    color: AppColors.heading, fontWeight: FontWeight.w700)),
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
                            child: CircularProgressIndicator(strokeWidth: 2))
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
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: _grid(),
                      ),
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
            label: 'Paste',
            icon: Icons.content_paste_rounded,
            onPressed: _pasteFromClipboard,
          ),
          const SizedBox(width: 4),
          Text('${_rows.length} rows · ${_columns.length} cols',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_on_rounded, size: 56, color: AppColors.textFaint),
          const SizedBox(height: 10),
          const Text('Empty table',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          const Text('Add columns, or paste data from Excel/Google Sheets',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
          const SizedBox(height: 14),
          PrimaryButton(
              label: 'Add Column', icon: Icons.add, onPressed: _addColumn),
        ],
      ),
    );
  }

  Widget _grid() {
    final columns = [
      for (var i = 0; i < _columns.length; i++)
        PlutoColumn(
          title: _columns[i],
          field: _field(i),
          type: PlutoColumnType.text(),
          width: 150,
          enableContextMenu: false,
          enableDropToResize: true,
          renderer: _statusRenderer,
        ),
    ];
    final rows = [
      for (final r in _rows)
        PlutoRow(cells: {
          for (var i = 0; i < _columns.length; i++)
            _field(i): PlutoCell(value: i < r.length ? r[i] : ''),
        }),
    ];

    return PlutoGrid(
      key: ValueKey('grid_$_structureKey'),
      columns: columns,
      rows: rows,
      onChanged: (e) {
        final ci = int.tryParse(e.column.field.substring(1)) ?? -1;
        if (ci < 0 || e.rowIdx >= _rows.length) return;
        while (_rows[e.rowIdx].length < _columns.length) {
          _rows[e.rowIdx].add('');
        }
        _rows[e.rowIdx][ci] = e.value?.toString() ?? '';
        if (!_dirty) setState(() => _dirty = true);
      },
      configuration: const PlutoGridConfiguration(
        columnSize: PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.none,
        ),
      ),
    );
  }

  Widget _statusRenderer(PlutoColumnRendererContext ctx) {
    final v = ctx.cell.value?.toString() ?? '';
    final sc = _statusColor(v);
    if (sc == null) {
      return Text(v, overflow: TextOverflow.ellipsis);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: sc.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(v,
          style: TextStyle(color: sc.fg, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis),
    );
  }

  // ── Mutations ──────────────────────────────────────────────────────────
  Future<void> _addColumn() async {
    final name = await _prompt('New column name', hint: 'e.g. Name / Date');
    if (name == null || name.trim().isEmpty) return;
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

  void _addRows(int n) {
    setState(() {
      for (var i = 0; i < n; i++) {
        _rows.add(List<String>.filled(_columns.length, ''));
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
    setState(() {
      if (_columns.isEmpty) {
        // First pasted line = headers, rest = rows.
        _columns = parsed.first.map((c) => c.trim()).toList();
        _rows = parsed.skip(1).map((r) {
          final row = List<String>.filled(_columns.length, '');
          for (var i = 0; i < r.length && i < _columns.length; i++) {
            row[i] = r[i].trim();
          }
          return row;
        }).toList();
      } else {
        // Append all pasted lines as rows, mapped to existing columns.
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
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      await ref.read(dataTableServiceProvider).save(
            widget.tableId,
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          PrimaryButton(label: 'OK', onPressed: () => Navigator.pop(ctx, c.text)),
        ],
      ),
    );
  }
}

/// Colour for a status-like cell value (attendance etc.).
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
