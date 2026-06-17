import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/drive_link_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/drive_providers.dart';

/// Manage linked Google Drive folders. Admin can attach as many Drive folders
/// as they like; once Google Drive access is connected (OAuth), the sheets
/// inside these folders feed into employee search.
class GoogleDriveAdminScreen extends ConsumerWidget {
  const GoogleDriveAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(driveLinksProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.heading),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/google-sheets'),
        ),
        title: const Text(
          'Google Drive',
          style:
              TextStyle(color: AppColors.heading, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddDialog(context, ref, user?.id ?? ''),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Link Drive'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SetupBanner(),
          const SizedBox(height: 16),
          const _ConnectCard(),
          const SizedBox(height: 16),
          links.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('$e',
                style: const TextStyle(color: AppColors.error)),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.folder_open_rounded,
                          size: 64, color: AppColors.textFaint),
                      const SizedBox(height: 12),
                      const Text('No Drive folders linked yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Link a Drive Folder',
                        icon: Icons.add,
                        onPressed: () =>
                            _showAddDialog(context, ref, user?.id ?? ''),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final link in list)
                    _DriveLinkCard(
                      link: link,
                      onDelete: () => _confirmDelete(context, ref, link),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final labelController = TextEditingController();
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Link Google Drive Folder',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'e.g. HR Records 2024',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Google Drive folder link',
                    hintText: 'https://drive.google.com/drive/folders/...',
                  ),
                  maxLines: 2,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (DriveLinkModel.extractFolderId(v).isEmpty) {
                      return 'Invalid Drive folder link';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can link as many Drive folders as you want.',
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
            label: 'Link',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref.read(driveLinksServiceProvider).addLink(
                      label: labelController.text.trim(),
                      url: urlController.text.trim(),
                      addedBy: userId,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('$e')));
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
    DriveLinkModel link,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Drive Link',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove "${link.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Remove',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(driveLinksServiceProvider).deleteLink(link.id);
    }
  }
}

class _ConnectCard extends ConsumerWidget {
  const _ConnectCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(driveConnectedProvider);
    final service = ref.watch(driveServiceProvider);

    return AppCard(
      child: Row(
        children: [
          Icon(
            connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: connected ? AppColors.pillGreenFg : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Google Drive connected' : 'Not connected',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.heading),
                ),
                Text(
                  connected
                      ? (service.connectedEmail ?? 'Reading linked folders')
                      : 'Connect to read sheets inside linked folders',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (connected)
            GhostButton(
              label: 'Disconnect',
              onPressed: () async {
                await service.disconnect();
                ref.read(driveConnectedProvider.notifier).state = false;
              },
            )
          else
            PrimaryButton(
              label: 'Connect',
              icon: Icons.login_rounded,
              onPressed: () async {
                try {
                  final ok = await service.connect();
                  ref.read(driveConnectedProvider.notifier).state = ok;
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign-in cancelled.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 20, color: AppColors.brandBlue),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup required to read Drive data',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.heading),
                ),
                SizedBox(height: 4),
                Text(
                  'You can link folders now. To actually read the sheets inside '
                  'them, a one-time Google Cloud setup (Drive API + OAuth Client '
                  'ID) is needed. See docs/DRIVE_SETUP.md.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveLinkCard extends StatelessWidget {
  const _DriveLinkCard({required this.link, required this.onDelete});
  final DriveLinkModel link;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              child: const Icon(Icons.folder_rounded,
                  color: AppColors.brandNavy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(link.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.heading)),
                  const SizedBox(height: 2),
                  Text(link.url,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textFaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
