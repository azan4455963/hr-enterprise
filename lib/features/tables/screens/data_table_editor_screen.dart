import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_table_providers.dart';

/// Spreadsheet-style editor for a custom table: add columns/rows, tap a cell to
/// edit (with quick status presets), colour-coded. Save writes to Firestore.
class DataTableEditorScreen extends ConsumerStatefulWidget {
  const DataTableEditorScreen({super.key, required this.tableId});
  final String tableId;

  @override
  ConsumerState<DataTableEditorScreen> createState() =>
      _DataTableEditorScreenState();
}

const _statusPresets = [
  'Present',
  'Absent',
  'Late coming',
  'Casual Leave',
  'Short Leave',
  'Medical Leave',
  '-',
];
const _cellWidth = 132.0;

class _DataTableEditorScreenState extends ConsumerState<DataTableEditorScreen> {
  List<String> _columns = [];
  List<List<String>> _rows = [];
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(dataTableProvider(widget.tableId));

    return tableAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (table) {
        if (table == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Table not found')),
          );
        }
        // Load server data once (don't clobber in-progress edits).
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
              // Toolbar
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GhostButton(
                      label: 'Add Column',
                      icon: Icons.view_column_outlined,
                      onPressed: _addColumn,
                    ),
                    const SizedBox(width: 10),
                    GhostButton(
                      label: 'Add Row',
                      icon: Icons.table_rows_outlined,
                      onPressed: _columns.isEmpty ? () {} : _addRow,
                    ),
                    const Spacer(),
                    Text('${_rows.length} rows · ${_columns.length} cols',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.cardBorder),
              Expanded(
                child: _columns.isEmpty
                    ? const Center(
                        child: Text('Add a column to begin',
                            style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildGrid(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const SizedBox(width: 40), // row-delete column
            for (var c = 0; c < _columns.length; c++)
              _HeaderCell(
                title: _columns[c],
                onRename: () => _renameColumn(c),
                onDelete: () => _deleteColumn(c),
              ),
          ],
        ),
        // Rows
        for (var r = 0; r < _rows.length; r++)
          Row(
            children: [
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 18, color: AppColors.textFaint),
                  tooltip: 'Delete row',
                  onPressed: () => _deleteRow(r),
                ),
              ),
              for (var c = 0; c < _columns.length; c++)
                _Cell(
                  value: c < _rows[r].length ? _rows[r][c] : '',
                  onTap: () => _editCell(r, c),
                ),
            ],
          ),
      ],
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
      _dirty = true;
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(List<String>.filled(_columns.length, ''));
      _dirty = true;
    });
  }

  Future<void> _renameColumn(int c) async {
    final name = await _prompt('Rename column', initial: _columns[c]);
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      _columns[c] = name.trim();
      _dirty = true;
    });
  }

  void _deleteColumn(int c) {
    setState(() {
      _columns.removeAt(c);
      for (final row in _rows) {
        if (c < row.length) row.removeAt(c);
      }
      _dirty = true;
    });
  }

  void _deleteRow(int r) {
    setState(() {
      _rows.removeAt(r);
      _dirty = true;
    });
  }

  Future<void> _editCell(int r, int c) async {
    final current = c < _rows[r].length ? _rows[r][c] : '';
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _CellEditDialog(initial: current),
    );
    if (value == null) return;
    setState(() {
      // pad row if needed
      while (_rows[r].length < _columns.length) {
        _rows[r].add('');
      }
      _rows[r][c] = value;
      _dirty = true;
    });
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

/// Colour for a status-like cell value.
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

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.title,
    required this.onRename,
    required this.onDelete,
  });
  final String title;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cellWidth,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.brandNavy.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppColors.heading),
                overflow: TextOverflow.ellipsis),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 16,
            onSelected: (v) {
              if (v == 'rename') onRename();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename column')),
              PopupMenuItem(value: 'delete', child: Text('Delete column')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(value);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: _cellWidth,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: sc?.bg ?? AppColors.surface,
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: sc != null ? FontWeight.w600 : FontWeight.w400,
            color: sc?.fg ?? AppColors.textBody,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _CellEditDialog extends StatefulWidget {
  const _CellEditDialog({required this.initial});
  final String initial;

  @override
  State<_CellEditDialog> createState() => _CellEditDialogState();
}

class _CellEditDialogState extends State<_CellEditDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit cell',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Value'),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 12),
            const Text('Quick status',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _statusPresets)
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _c.text = s),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        PrimaryButton(
            label: 'Save', onPressed: () => Navigator.pop(context, _c.text)),
      ],
    );
  }
}
