import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/google_sheet_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/google_sheets_providers.dart';
import '../../../providers/service_providers.dart';

class GoogleSheetViewerScreen extends ConsumerStatefulWidget {
  final GoogleSheetModel sheet;

  const GoogleSheetViewerScreen({super.key, required this.sheet});

  @override
  ConsumerState<GoogleSheetViewerScreen> createState() =>
      _GoogleSheetViewerScreenState();
}

class _GoogleSheetViewerScreenState
    extends ConsumerState<GoogleSheetViewerScreen> {
  GoogleSheetModel get sheet => widget.sheet;

  bool _importing = false;

  // Column management state
  List<String> _columnNames = [];
  List<int> _columnOrder = [];
  bool _columnsInitialized = false;

  // Row data (mutable for cell moves)
  List<List<String>> _dataRows = [];

  @override
  Widget build(BuildContext context) {
    final sheetData = ref.watch(
      googleSheetDataProvider((sheetId: sheet.sheetId, gid: sheet.gid)),
    );
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canImport = user?.hasPermission('employees_create') ?? false;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.heading),
          onPressed: () => context.pop(),
        ),
        title: Text(
          sheet.title,
          style: const TextStyle(
            color: AppColors.heading,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (canImport)
            TextButton.icon(
              onPressed: _importing
                  ? null
                  : () => _importEmployees(context, user!.id),
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(_importing ? 'Importing…' : 'Import to Employees'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            tooltip: 'Refresh data',
            onPressed: () {
              ref.invalidate(
                googleSheetDataProvider((
                  sheetId: sheet.sheetId,
                  gid: sheet.gid,
                )),
              );
              setState(() => _columnsInitialized = false);
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.open_in_new_rounded,
              color: AppColors.brandNavy,
            ),
            tooltip: 'Open in Google Sheets',
            onPressed: () => _openInSheets(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: sheetData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _buildErrorView(context, err.toString()),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Text(
                'Sheet is empty',
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),
            );
          }
          return _buildTableView(context, rows);
        },
      ),
    );
  }

  void _initColumnsFromRows(List<List<String>> rows) {
    if (_columnsInitialized) return;
    final headerRow = rows.isNotEmpty ? rows.first : <String>[];
    final dataRows = rows.length > 1 ? rows.sublist(1) : <List<String>>[];
    final columnCount = headerRow.isNotEmpty
        ? headerRow.length
        : (dataRows.isNotEmpty ? dataRows.first.length : 1);

    _columnNames = List.generate(
      columnCount,
      (i) => i < headerRow.length ? headerRow[i] : 'Column ${i + 1}',
    );
    _columnOrder = List.generate(columnCount, (i) => i);
    _dataRows = dataRows.map((r) => List<String>.from(r)).toList();
    _columnsInitialized = true;
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 72,
              color: AppColors.textFaint,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load sheet data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openInSheets(context),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open in Google Sheets'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandNavy,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showPublishGuide(context),
              icon: const Icon(Icons.help_outline),
              label: const Text('How to publish a sheet?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableView(BuildContext context, List<List<String>> rows) {
    // Initialize column management state on first build
    _initColumnsFromRows(rows);

    return Column(
      children: [
        // Info bar with column actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: AppColors.surface,
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                '${_dataRows.length} rows · ${_columnOrder.length} columns',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              // Add column button
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: AppColors.brandNavy,
                ),
                tooltip: 'Add new column',
                onPressed: () => _showAddColumnDialog(context),
              ),
              const SizedBox(width: 4),
              Text(
                'Last synced: just now',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.brandNavy.withValues(alpha: 0.05),
                ),
                border: TableBorder.all(
                  color: AppColors.cardBorder,
                  width: 0.5,
                ),
                columnSpacing: 24,
                horizontalMargin: 16,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columns: List.generate(_columnOrder.length, (i) {
                  final origIdx = _columnOrder[i];
                  final name = origIdx < _columnNames.length
                      ? _columnNames[origIdx]
                      : 'Column ${origIdx + 1}';
                  return DataColumn(
                    label: _ColumnHeader(
                      name: name,
                      index: i,
                      origIdx: origIdx,
                      totalColumns: _columnOrder.length,
                      totalRows: _dataRows.length,
                      onRename: () => _showRenameColumnDialog(context, origIdx),
                      onMoveLeft: i > 0 ? () => _moveColumn(i, i - 1) : null,
                      onMoveRight: i < _columnOrder.length - 1
                          ? () => _moveColumn(i, i + 1)
                          : null,
                      onMoveToStart: i > 0 ? () => _moveColumn(i, 0) : null,
                      onMoveToEnd: i < _columnOrder.length - 1
                          ? () => _moveColumn(i, _columnOrder.length - 1)
                          : null,
                      onAddBefore: () => _showAddColumnAtDialog(context, i),
                      onAddAfter: () => _showAddColumnAtDialog(context, i + 1),
                      onDelete: () => _deleteColumn(origIdx),
                      onMoveCell: () => _showMoveCellDialog(context, origIdx),
                    ),
                  );
                }),
                rows: List.generate(_dataRows.length, (rowIdx) {
                  final row = _dataRows[rowIdx];
                  return DataRow(
                    color: WidgetStateProperty.all(
                      rowIdx.isEven
                          ? Colors.transparent
                          : AppColors.brandNavy.withValues(alpha: 0.03),
                    ),
                    cells: List.generate(_columnOrder.length, (i) {
                      final origIdx = _columnOrder[i];
                      return DataCell(
                        Text(
                          origIdx < row.length ? row[origIdx] : '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textBody,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Column operations ──────────────────────────────────────────────

  void _moveColumn(int fromDisplayIdx, int toDisplayIdx) {
    setState(() {
      final item = _columnOrder.removeAt(fromDisplayIdx);
      _columnOrder.insert(toDisplayIdx, item);
    });
  }

  void _showRenameColumnDialog(BuildContext context, int origIdx) {
    final controller = TextEditingController(text: _columnNames[origIdx]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rename Column',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Column name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            _applyRename(origIdx, controller.text.trim(), ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Rename',
            onPressed: () {
              _applyRename(origIdx, controller.text.trim(), ctx);
            },
          ),
        ],
      ),
    );
  }

  void _applyRename(int origIdx, String newName, BuildContext dialogCtx) {
    if (newName.isEmpty) return;
    setState(() {
      _columnNames[origIdx] = newName;
    });
    Navigator.pop(dialogCtx);
  }

  void _showAddColumnDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Column',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Column name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            _applyAddColumn(controller.text.trim(), _columnOrder.length, ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Add',
            onPressed: () {
              _applyAddColumn(controller.text.trim(), _columnOrder.length, ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showAddColumnAtDialog(BuildContext context, int atDisplayIdx) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Column',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Column name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            _applyAddColumn(controller.text.trim(), atDisplayIdx, ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Add',
            onPressed: () {
              _applyAddColumn(controller.text.trim(), atDisplayIdx, ctx);
            },
          ),
        ],
      ),
    );
  }

  void _applyAddColumn(String name, int atDisplayIdx, BuildContext dialogCtx) {
    if (name.isEmpty) return;
    setState(() {
      final newOrigIdx = _columnNames.length;
      _columnNames.add(name);
      _columnOrder.insert(atDisplayIdx, newOrigIdx);
      // Add empty cell for each existing row
      for (var row in _dataRows) {
        row.add('');
      }
    });
    Navigator.pop(dialogCtx);
  }

  void _deleteColumn(int origIdx) {
    final name = _columnNames[origIdx];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Column',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete column "$name"?\n\n'
          'This only hides the column from view. Data in other sheets may still contain it.',
          style: const TextStyle(fontSize: 14, color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Delete',
            onPressed: () {
              setState(() {
                _columnOrder.removeWhere((idx) => idx == origIdx);
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ── Move Cell Value ────────────────────────────────────────────────

  void _showMoveCellDialog(BuildContext context, int colOrigIdx) {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final columnName = colOrigIdx < _columnNames.length
        ? _columnNames[colOrigIdx]
        : 'Column ${colOrigIdx + 1}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Move Cell — $columnName',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Move a cell value from one row to another within this column.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: fromController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'From row # (1-${_dataRows.length})',
                border: const OutlineInputBorder(),
                helperText: 'Current row of the cell value',
                helperStyle: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'To row # (1-${_dataRows.length})',
                border: const OutlineInputBorder(),
                helperText: 'Target row to place the value',
                helperStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Move',
            onPressed: () {
              _applyMoveCell(
                colOrigIdx,
                fromController.text.trim(),
                toController.text.trim(),
                ctx,
              );
            },
          ),
        ],
      ),
    );
  }

  void _applyMoveCell(
    int colOrigIdx,
    String fromStr,
    String toStr,
    BuildContext dialogCtx,
  ) {
    final fromRow = int.tryParse(fromStr);
    final toRow = int.tryParse(toStr);

    if (fromRow == null || toRow == null) {
      _snack('Please enter valid row numbers.');
      return;
    }

    // Convert to 0-based index
    final fromIdx = fromRow - 1;
    final toIdx = toRow - 1;

    if (fromIdx < 0 || fromIdx >= _dataRows.length) {
      _snack('From row #$fromRow is out of range (1-${_dataRows.length}).');
      return;
    }
    if (toIdx < 0 || toIdx >= _dataRows.length) {
      _snack('To row #$toRow is out of range (1-${_dataRows.length}).');
      return;
    }

    setState(() {
      // Ensure both rows have enough columns
      while (_dataRows[fromIdx].length <= colOrigIdx) {
        _dataRows[fromIdx].add('');
      }
      while (_dataRows[toIdx].length <= colOrigIdx) {
        _dataRows[toIdx].add('');
      }

      // Move the cell value
      final value = _dataRows[fromIdx][colOrigIdx];
      _dataRows[toIdx][colOrigIdx] = value;
      _dataRows[fromIdx][colOrigIdx] = '';
    });

    Navigator.pop(dialogCtx);
    _snack(
      'Moved cell from row #$fromRow to row #$toRow in "${_columnNames[colOrigIdx]}".',
    );
  }

  // ── Import ─────────────────────────────────────────────────────────

  Future<void> _importEmployees(BuildContext context, String userId) async {
    final rows = ref
        .read(googleSheetDataProvider((sheetId: sheet.sheetId, gid: sheet.gid)))
        .valueOrNull;
    if (rows == null || rows.length < 2) {
      _snack('Sheet has no data rows to import.');
      return;
    }

    final service = ref.read(googleSheetsServiceProvider);
    final parsed = service.parseEmployees(rows);

    if (parsed.isEmpty) {
      _snack(
        'No employee names found. Make sure the sheet has a "Name" column.',
      );
      return;
    }

    // Confirm with a preview.
    final sample = parsed.employees.take(3).map((e) {
      final bits = <String>[e.fullName];
      if (e.departmentName?.isNotEmpty ?? false) bits.add(e.departmentName!);
      if (e.position?.isNotEmpty ?? false) bits.add(e.position!);
      if (e.salary != null) bits.add('Rs ${e.salary!.toStringAsFixed(0)}');
      return bits.join(' · ');
    }).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Import to Employees',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${parsed.count} employee(s) found in this sheet.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
            if (parsed.skippedRows > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${parsed.skippedRows} row(s) skipped (no name).',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Preview:',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            for (final s in sample)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $s',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            if (parsed.count > sample.length)
              Text(
                '…and ${parsed.count - sample.length} more',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Existing employees (same email/name) will be skipped.',
              style: TextStyle(fontSize: 11, color: AppColors.textFaint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Import ${parsed.count}',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      final result = await ref
          .read(employeeServiceProvider)
          .importEmployees(parsed.employees, userId: userId);
      _snack(
        'Imported ${result.created} employee(s)'
        '${result.duplicates > 0 ? ' · ${result.duplicates} duplicate(s) skipped' : ''}.',
      );
    } catch (e) {
      _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openInSheets(BuildContext context) async {
    final url = sheet.url;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the sheet URL')),
        );
      }
    }
  }

  void _showPublishGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'How to Publish a Google Sheet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuideStep(number: '1', text: 'Open your Google Sheet'),
            _GuideStep(
              number: '2',
              text: 'Click File > Share > Publish to web',
            ),
            _GuideStep(
              number: '3',
              text: 'Choose "Entire Document" or a specific sheet',
            ),
            _GuideStep(number: '4', text: 'Click "Publish" and confirm'),
            SizedBox(height: 16),
            Text(
              'Note: Published sheets are publicly accessible.\n'
              'Do not publish sensitive/confidential data.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// A column header widget that shows a context menu on right-click / long-press.
class _ColumnHeader extends StatelessWidget {
  final String name;
  final int index;
  final int origIdx;
  final int totalColumns;
  final int totalRows;
  final VoidCallback onRename;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final VoidCallback? onMoveToStart;
  final VoidCallback? onMoveToEnd;
  final VoidCallback onAddBefore;
  final VoidCallback onAddAfter;
  final VoidCallback onDelete;
  final VoidCallback onMoveCell;

  const _ColumnHeader({
    required this.name,
    required this.index,
    required this.origIdx,
    required this.totalColumns,
    required this.totalRows,
    required this.onRename,
    this.onMoveLeft,
    this.onMoveRight,
    this.onMoveToStart,
    this.onMoveToEnd,
    required this.onAddBefore,
    required this.onAddAfter,
    required this.onDelete,
    required this.onMoveCell,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      onSecondaryTap: () => _showContextMenu(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.heading,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down_rounded,
            size: 16,
            color: AppColors.textFaint.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(0, 0, 0, 0),
      surfaceTintColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        // ── Rename ────────────────────────────────
        PopupMenuItem(
          value: 'rename',
          child: _MenuRow(icon: Icons.edit_rounded, text: 'Rename column'),
        ),
        // ── Move Cell ─────────────────────────────
        PopupMenuItem(
          value: 'move_cell',
          child: _MenuRow(
            icon: Icons.swap_vert_rounded,
            text: 'Move cell value',
          ),
        ),
        // ── Move ──────────────────────────────────
        if (onMoveLeft != null || onMoveRight != null) ...[
          const PopupMenuDivider(),
          if (onMoveLeft != null)
            PopupMenuItem(
              value: 'move_left',
              child: _MenuRow(
                icon: Icons.chevron_left_rounded,
                text: 'Move left',
              ),
            ),
          if (onMoveRight != null)
            PopupMenuItem(
              value: 'move_right',
              child: _MenuRow(
                icon: Icons.chevron_right_rounded,
                text: 'Move right',
              ),
            ),
          if (onMoveToStart != null)
            PopupMenuItem(
              value: 'move_start',
              child: _MenuRow(
                icon: Icons.first_page_rounded,
                text: 'Move to start',
              ),
            ),
          if (onMoveToEnd != null)
            PopupMenuItem(
              value: 'move_end',
              child: _MenuRow(
                icon: Icons.last_page_rounded,
                text: 'Move to end',
              ),
            ),
        ],
        // ── Add ───────────────────────────────────
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'add_before',
          child: _MenuRow(icon: Icons.add_rounded, text: 'Add column before'),
        ),
        PopupMenuItem(
          value: 'add_after',
          child: _MenuRow(icon: Icons.add_rounded, text: 'Add column after'),
        ),
        // ── Delete ────────────────────────────────
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            text: 'Delete column',
            color: AppColors.error,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'rename':
          onRename();
        case 'move_cell':
          onMoveCell();
        case 'move_left':
          onMoveLeft?.call();
        case 'move_right':
          onMoveRight?.call();
        case 'move_start':
          onMoveToStart?.call();
        case 'move_end':
          onMoveToEnd?.call();
        case 'add_before':
          onAddBefore();
        case 'add_after':
          onAddAfter();
        case 'delete':
          onDelete();
      }
    });
  }
}

/// A row inside a popup menu item with an icon and text.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MenuRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textBody;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(fontSize: 13.5, color: c)),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String text;

  const _GuideStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.brandNavy,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}
