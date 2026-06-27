import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/asset_model.dart';
import '../../../providers/asset_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';

const _categories = [
  'Laptop',
  'Desktop',
  'Phone',
  'Monitor',
  'Keyboard / Mouse',
  'Furniture',
  'Vehicle',
  'SIM / Connection',
  'Equipment',
  'Other',
];

/// Company assets: add equipment, assign it to employees, see who has what.
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final assetsAsync = ref.watch(assetsProvider);
    final userId = ref.watch(currentUserProvider).valueOrNull?.id ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeading(
                  title: 'Assets',
                  subtitle:
                      'Track equipment — laptops, phones, etc. — and who has it.',
                ),
              ),
              PrimaryButton(
                label: 'Add Asset',
                icon: Icons.add,
                onPressed: () => _showAssetDialog(context, ref, userId),
              ),
            ],
          ),
          const SizedBox(height: 18),
          assetsAsync.when(
            loading: () =>
                const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator())),
            error: (e, _) => _ErrorCard(error: e),
            data: (assets) {
              if (assets.isEmpty) {
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        const Icon(Icons.devices_other_rounded,
                            size: 52, color: AppColors.textFaint),
                        const SizedBox(height: 10),
                        const Text('No assets yet',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted)),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: 'Add your first asset',
                          icon: Icons.add,
                          onPressed: () =>
                              _showAssetDialog(context, ref, userId),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final assigned = assets
                  .where((a) => a.status == AssetStatus.assigned)
                  .length;
              final available = assets
                  .where((a) => a.status == AssetStatus.available)
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _stat('Total', assets.length, AppColors.brandNavy),
                      const SizedBox(width: 10),
                      _stat('Assigned', assigned, AppColors.success),
                      const SizedBox(width: 10),
                      _stat('Available', available, AppColors.brandBlue),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final a in assets)
                    _AssetTile(asset: a, userId: userId),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 20, color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final isPerm = error.toString().toLowerCase().contains('permission');
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppColors.warning, size: 28),
            const SizedBox(height: 10),
            Text(
              isPerm
                  ? 'Assets need a one-time setup.'
                  : 'Could not load assets.',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.heading),
            ),
            const SizedBox(height: 6),
            Text(
              isPerm
                  ? 'Deploy the Firestore rules once so the assets collection '
                      'is allowed:\n\n    firebase deploy --only firestore:rules'
                  : '$error',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends ConsumerWidget {
  const _AssetTile({required this.asset, required this.userId});
  final AssetModel asset;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (statusLabel, statusColor) = switch (asset.status) {
      AssetStatus.assigned => ('Assigned', AppColors.success),
      AssetStatus.available => ('Available', AppColors.brandBlue),
      AssetStatus.retired => ('Retired', AppColors.textFaint),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.brandNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.devices_rounded,
                  color: AppColors.brandNavy, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppColors.heading)),
                  const SizedBox(height: 2),
                  Text(
                    '${asset.category}'
                    '${(asset.serialNumber?.isNotEmpty ?? false) ? "  ·  SN ${asset.serialNumber}" : ""}'
                    '${asset.assignedToName != null ? "  ·  ${asset.assignedToName}" : ""}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted),
              onSelected: (v) {
                switch (v) {
                  case 'assign':
                    _showAssignDialog(context, ref, asset, userId);
                  case 'unassign':
                    ref
                        .read(assetServiceProvider)
                        .unassign(asset.id, userId: userId);
                  case 'edit':
                    _showAssetDialog(context, ref, userId, existing: asset);
                  case 'delete':
                    _confirmDelete(context, ref, asset, userId);
                }
              },
              itemBuilder: (_) => [
                if (asset.status == AssetStatus.assigned)
                  const PopupMenuItem(
                      value: 'unassign', child: Text('Unassign / return'))
                else
                  const PopupMenuItem(
                      value: 'assign', child: Text('Assign to employee')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      AssetModel asset, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete asset'),
        content: Text('Delete "${asset.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(assetServiceProvider).delete(asset.id, userId: userId);
    }
  }
}

// ── Add / edit dialog ───────────────────────────────────────────────────────
void _showAssetDialog(BuildContext context, WidgetRef ref, String userId,
    {AssetModel? existing}) {
  final isEdit = existing != null;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?.name ?? '');
  final serial = TextEditingController(text: existing?.serialNumber ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  var category = existing?.category ?? 'Laptop';
  if (!_categories.contains(category)) category = 'Other';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Asset' : 'Add Asset'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Asset name', hintText: 'e.g. Dell Latitude'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => category = v ?? category,
              ),
              TextFormField(
                controller: serial,
                decoration: const InputDecoration(labelText: 'Serial number'),
              ),
              TextFormField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final svc = ref.read(assetServiceProvider);
            final messenger = ScaffoldMessenger.of(ctx);
            try {
              if (isEdit) {
                await svc.update(
                  existing.copyWith(
                    name: name.text.trim(),
                    category: category,
                    serialNumber: serial.text.trim(),
                    notes: notes.text.trim(),
                  ),
                  userId: userId,
                );
              } else {
                await svc.create(
                  AssetModel(
                    id: '',
                    name: name.text.trim(),
                    category: category,
                    serialNumber: serial.text.trim(),
                    notes: notes.text.trim(),
                  ),
                  userId: userId,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('$e')));
            }
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    ),
  );
}

// ── Assign dialog ───────────────────────────────────────────────────────────
void _showAssignDialog(
    BuildContext context, WidgetRef ref, AssetModel asset, String userId) {
  final employees = ref.read(employeesProvider).valueOrNull ?? const [];
  String? selectedId;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Assign "${asset.name}"'),
      content: DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Employee'),
        items: [
          for (final e in employees)
            DropdownMenuItem(value: e.id, child: Text(e.fullName)),
        ],
        onChanged: (v) => selectedId = v,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (selectedId == null) return;
            final emp = employees.firstWhere((e) => e.id == selectedId);
            final messenger = ScaffoldMessenger.of(ctx);
            try {
              await ref.read(assetServiceProvider).assign(
                    asset.id,
                    employeeId: emp.id,
                    employeeName: emp.fullName,
                    userId: userId,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('$e')));
            }
          },
          child: const Text('Assign'),
        ),
      ],
    ),
  );
}
