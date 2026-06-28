import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/excel_import.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/data_table_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_table_providers.dart';
import '../../../providers/service_providers.dart';

/// Lists custom in-app tables. Create, open, rename, delete.
class DataTablesScreen extends ConsumerWidget {
  const DataTablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final tables = ref.watch(dataTablesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeading(
                  title: 'Tables',
                  subtitle:
                      'Build your own data tables — add columns and rows, fill in records.',
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _importExcel(context, ref, user?.id ?? ''),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Import Excel'),
                  ),
                  const SizedBox(width: 10),
                  PrimaryButton(
                    label: 'New Table',
                    icon: Icons.add,
                    onPressed: () => _create(context, ref, user?.id ?? ''),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          tables.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: AppColors.error)),
            data: (list) {
              if (list.isEmpty) {
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        const Icon(Icons.table_view_rounded,
                            size: 56, color: AppColors.textFaint),
                        const SizedBox(height: 10),
                        const Text('No tables yet',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted)),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: 'Create your first table',
                          icon: Icons.add,
                          onPressed: () => _create(context, ref, user?.id ?? ''),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final t in list)
                    _TableCard(
                      table: t,
                      onOpen: () => context.go('/tables/${t.id}'),
                      onRename: () =>
                          _rename(context, ref, t, user?.id ?? ''),
                      onExport: () => _exportExcel(context, ref, t),
                      onDelete: () =>
                          _confirmDelete(context, ref, t, user?.id ?? ''),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _create(
      BuildContext context, WidgetRef ref, String userId) async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Table',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Choose what to create.'),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'blank'),
              child: const Text('Blank table')),
          PrimaryButton(
            label: 'Attendance workbook (12 months)',
            icon: Icons.event_available_rounded,
            onPressed: () => Navigator.pop(ctx, 'attendance'),
          ),
          PrimaryButton(
            label: 'Salary workbook (12 months)',
            icon: Icons.payments_rounded,
            onPressed: () => Navigator.pop(ctx, 'salary'),
          ),
        ],
      ),
    );
    if (type == null) return;
    if (!context.mounted) return;

    if (type == 'attendance') {
      final name = await _nameDialog(context,
          title: 'New Attendance Workbook',
          hint: 'Department name — e.g. IT, Billing');
      if (name == null || name.trim().isEmpty) return;
      final id = await ref.read(dataTableServiceProvider).createAttendanceWorkbook(
            name: name.trim(),
            year: DateTime.now().year,
            userId: userId,
          );
      if (context.mounted) context.go('/tables/$id');
    } else if (type == 'salary') {
      final name = await _nameDialog(context,
          title: 'New Salary Workbook', hint: 'e.g. 2026 Salaries');
      if (name == null || name.trim().isEmpty) return;
      final id = await ref.read(dataTableServiceProvider).createSalaryWorkbook(
            name: name.trim(),
            year: DateTime.now().year,
            userId: userId,
          );
      if (context.mounted) context.go('/tables/$id');
    } else {
      final name = await _nameDialog(context, title: 'New Table');
      if (name == null || name.trim().isEmpty) return;
      final id = await ref
          .read(dataTableServiceProvider)
          .create(name: name.trim(), userId: userId);
      if (context.mounted) context.go('/tables/$id');
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, DataTableModel t,
      String userId) async {
    final name = await _nameDialog(context, title: 'Rename Table', initial: t.name);
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(dataTableServiceProvider)
        .rename(t.id, name: name.trim(), userId: userId);
  }

  /// Pick an .xlsx file and import it as a brand-new table (one tab per sheet).
  Future<void> _importExcel(
      BuildContext context, WidgetRef ref, String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not read the file.')));
      return;
    }
    List<DataSheet> sheets;
    try {
      sheets = parseExcelWorkbook(bytes);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text("That doesn't look like a valid .xlsx file.")));
      return;
    }
    if (sheets.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No data found in that file.')));
      return;
    }
    final name =
        file.name.replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '');
    final id = await ref.read(dataTableServiceProvider).importWorkbook(
          name: name,
          sheets: sheets,
          userId: userId,
        );
    if (context.mounted) context.go('/tables/$id');
  }

  /// Export a table to an .xlsx download (one worksheet per tab). Read-only.
  Future<void> _exportExcel(
      BuildContext context, WidgetRef ref, DataTableModel t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes =
          await ref.read(exportServiceProvider).buildTableWorkbookExcel(t);
      final safe = t.name.trim().isEmpty
          ? 'table'
          : t.name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '_');
      await saveBytes(
        bytes,
        '$safe.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<String?> _nameDialog(BuildContext context,
      {required String title,
      String initial = '',
      String hint = 'e.g. June 2026 Attendance'}) {
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
          decoration: InputDecoration(
            labelText: 'Table name',
            hintText: hint,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          PrimaryButton(
              label: 'Save', onPressed: () => Navigator.pop(ctx, c.text)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      DataTableModel t, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Table',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Delete "${t.name}" and all its data?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          PrimaryButton(
              label: 'Delete', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(dataTableServiceProvider).delete(t.id, userId: userId);
    }
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.onOpen,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
  });
  final DataTableModel table;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.grid_on_rounded,
                    color: AppColors.brandNavy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(table.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.heading)),
                    const SizedBox(height: 2),
                    Text(
                      '${table.sheets.length > 1 ? "${table.sheets.length} tabs · " : ""}'
                      '${table.columns.length} columns · ${table.rows.length} rows'
                      '${table.updatedAt != null ? " · updated ${DateFormat('dd MMM').format(table.updatedAt!)}" : ""}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'export') onExport();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Rename'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Row(children: [
                      Icon(Icons.file_download_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Export to Excel'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ]),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
