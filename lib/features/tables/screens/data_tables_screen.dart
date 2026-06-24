import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/data_table_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_table_providers.dart';

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
              PrimaryButton(
                label: 'New Table',
                icon: Icons.add,
                onPressed: () => _create(context, ref, user?.id ?? ''),
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
        ],
      ),
    );
    if (type == null) return;

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
    required this.onDelete,
  });
  final DataTableModel table;
  final VoidCallback onOpen;
  final VoidCallback onRename;
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
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
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
