import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/google_sheet_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/google_sheets_providers.dart';

class GoogleSheetsAdminScreen extends ConsumerWidget {
  const GoogleSheetsAdminScreen({super.key, this.embedded = false});

  /// When shown inside the Sheets & Drive hub (a tab), drop the back button
  /// and title and keep only the "Add Sheet" action.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheets = ref.watch(googleSheetsListProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: embedded
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              automaticallyImplyLeading: false,
              toolbarHeight: 52,
              actions: [
                TextButton.icon(
                  onPressed: () =>
                      _showAddSheetDialog(context, ref, user?.id ?? ''),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Sheet'),
                ),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.heading),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                'Attached Sheets',
                style: TextStyle(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () =>
                      _showAddSheetDialog(context, ref, user?.id ?? ''),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Sheet'),
                ),
              ],
            ),
      body: sheets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_chart_outlined,
                    size: 72,
                    color: AppColors.textFaint,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No sheets attached yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "Add Sheet" to attach a Google Sheet',
                    style: TextStyle(color: AppColors.textFaint),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Add Sheet',
                    icon: Icons.add,
                    onPressed: () =>
                        _showAddSheetDialog(context, ref, user?.id ?? ''),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final sheet = list[index];
              return _SheetCard(
                sheet: sheet,
                onDelete: () => _confirmDelete(context, ref, sheet),
                onEdit: () => _showEditSheetDialog(context, ref, sheet),
                onTap: () => _viewSheet(context, ref, sheet),
                onToggleSync: () => _toggleSync(context, ref, sheet),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleSync(
    BuildContext context,
    WidgetRef ref,
    GoogleSheetModel sheet,
  ) async {
    final enabling = !sheet.syncEmployees;
    try {
      await ref
          .read(googleSheetsServiceProvider)
          .setSyncEmployees(sheet.id, enabling);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabling
                  ? 'Auto-sync ON — "${sheet.title}" will keep employees updated.'
                  : 'Auto-sync OFF for "${sheet.title}".',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _viewSheet(BuildContext context, WidgetRef ref, GoogleSheetModel sheet) {
    context.push('/google-sheets/${sheet.id}', extra: sheet);
  }

  Future<void> _showAddSheetDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Attach Google Sheet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Sheet Title',
                    hintText: 'e.g. Employee Directory',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Google Sheets URL',
                    hintText: 'https://docs.google.com/spreadsheets/d/...',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final sid = GoogleSheetModel.extractSheetId(v);
                    if (sid.isEmpty) return 'Invalid Google Sheets URL';
                    return null;
                  },
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure the sheet is published: File > Share > Publish to web',
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Attach',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref
                    .read(googleSheetsServiceProvider)
                    .addSheet(
                      title: titleController.text.trim(),
                      url: urlController.text.trim(),
                      addedBy: userId,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheetDialog(
    BuildContext context,
    WidgetRef ref,
    GoogleSheetModel sheet,
  ) async {
    final titleController = TextEditingController(text: sheet.title);
    final urlController = TextEditingController(text: sheet.url);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Sheet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Sheet Title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Google Sheets URL',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final sid = GoogleSheetModel.extractSheetId(v);
                    if (sid.isEmpty) return 'Invalid Google Sheets URL';
                    return null;
                  },
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Save',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref
                    .read(googleSheetsServiceProvider)
                    .updateSheet(
                      sheet.id,
                      title: titleController.text.trim(),
                      url: urlController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    GoogleSheetModel sheet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Sheet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('Remove "${sheet.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(googleSheetsServiceProvider).deleteSheet(sheet.id);
    }
  }
}

class _SheetCard extends StatelessWidget {
  final GoogleSheetModel sheet;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTap;
  final VoidCallback onToggleSync;

  const _SheetCard({
    required this.sheet,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
    required this.onToggleSync,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: AppColors.brandNavy,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sheet.url,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sheet.syncEmployees) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.pillGreenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_rounded,
                                size: 12, color: AppColors.pillGreenFg),
                            SizedBox(width: 4),
                            Text(
                              'Auto-syncing to Employees',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pillGreenFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'sync') onToggleSync();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined, size: 20),
                      title: Text('Edit'),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sync',
                    child: ListTile(
                      leading: Icon(
                        sheet.syncEmployees
                            ? Icons.sync_disabled_rounded
                            : Icons.sync_rounded,
                        size: 20,
                        color: AppColors.brandNavy,
                      ),
                      title: Text(
                        sheet.syncEmployees
                            ? 'Turn off auto-sync'
                            : 'Auto-sync to Employees',
                      ),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.error),
                      ),
                      dense: true,
                    ),
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
