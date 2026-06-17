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

  @override
  Widget build(BuildContext context) {
    final sheetData = ref.watch(googleSheetDataProvider((sheetId: sheet.sheetId, gid: sheet.gid)));
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
            onPressed: () =>
                ref.invalidate(googleSheetDataProvider((sheetId: sheet.sheetId, gid: sheet.gid))),
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
    final headerRow = rows.isNotEmpty ? rows.first : <String>[];
    final dataRows = rows.length > 1 ? rows.sublist(1) : <List<String>>[];
    final columnCount = headerRow.isNotEmpty
        ? headerRow.length
        : (dataRows.isNotEmpty ? dataRows.first.length : 1);

    return Column(
      children: [
        // Info bar
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
                '${dataRows.length} rows · $columnCount columns',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
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
                dataRowMinHeight: 40,
                dataRowMaxHeight: 60,
                columns: List.generate(
                  columnCount,
                  (i) => DataColumn(
                    label: Text(
                      i < headerRow.length ? headerRow[i] : 'Column ${i + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.heading,
                      ),
                    ),
                  ),
                ),
                rows: dataRows
                    .map(
                      (row) => DataRow(
                        cells: List.generate(
                          columnCount,
                          (i) => DataCell(
                            Text(
                              i < row.length ? row[i] : '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textBody,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _importEmployees(BuildContext context, String userId) async {
    final rows = ref.read(googleSheetDataProvider((sheetId: sheet.sheetId, gid: sheet.gid))).valueOrNull;
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
        title: const Text('Import to Employees',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${parsed.count} employee(s) found in this sheet.',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heading)),
            if (parsed.skippedRows > 0) ...[
              const SizedBox(height: 4),
              Text('${parsed.skippedRows} row(s) skipped (no name).',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            const SizedBox(height: 12),
            const Text('Preview:',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            for (final s in sample)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $s',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textBody)),
              ),
            if (parsed.count > sample.length)
              Text('…and ${parsed.count - sample.length} more',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textFaint)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
