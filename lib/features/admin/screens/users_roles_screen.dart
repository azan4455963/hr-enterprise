import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

/// Admin-only: see all users and manage their roles (Admin / Director /
/// Employee), assign director departments, and enable/disable accounts.
class UsersRolesScreen extends ConsumerWidget {
  const UsersRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final usersAsync = ref.watch(usersProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Users & Roles',
            subtitle:
                'Manage who is Admin, Director or Employee. Admin only.',
          ),
          const SizedBox(height: 20),
          usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: AppColors.error)),
            data: (users) {
              if (users.isEmpty) {
                return const Text('No users yet',
                    style: TextStyle(color: AppColors.textMuted));
              }
              return Column(
                children: [
                  for (final u in users)
                    _UserCard(user: u, isSelf: u.id == me?.id),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user, required this.isSelf});
  final UserModel user;
  final bool isSelf;

  StatusPill get _rolePill {
    switch (user.role) {
      case RolePermissions.superAdmin:
        return StatusPill.amber('Admin');
      case RolePermissions.manager:
        return StatusPill.green('Director');
      default:
        return StatusPill.blue('Employee');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            InitialAvatar(name: user.displayName ?? user.email, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(user.displayName ?? user.email,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.heading),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      _rolePill,
                      if (!user.isActive) ...[
                        const SizedBox(width: 6),
                        StatusPill.red('Disabled'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.role == RolePermissions.manager &&
                            user.departments.isNotEmpty
                        ? '${user.email} · ${user.departments.join(", ")}'
                        : user.email,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelf)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('You',
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted),
                onSelected: (v) => _onAction(context, ref, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'role',
                    child: Row(children: [
                      Icon(Icons.badge_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Change role'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                        user.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline,
                        size: 18,
                        color: user.isActive
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(width: 10),
                      Text(user.isActive
                          ? 'Disable account'
                          : 'Enable account'),
                    ]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    final service = ref.read(userAdminServiceProvider);
    if (action == 'toggle') {
      await service.setActive(
          uid: user.id, active: !user.isActive, adminId: me?.id ?? '');
      return;
    }
    if (action == 'role') {
      await showDialog(
        context: context,
        builder: (_) => _RoleDialog(user: user, adminId: me?.id ?? ''),
      );
    }
  }
}

class _RoleDialog extends ConsumerStatefulWidget {
  const _RoleDialog({required this.user, required this.adminId});
  final UserModel user;
  final String adminId;

  @override
  ConsumerState<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends ConsumerState<_RoleDialog> {
  late String _role = widget.user.role;
  late final Set<String> _depts = {...widget.user.departments};

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider).valueOrNull ?? [];
    final isDirector = _role == RolePermissions.manager;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Role — ${widget.user.displayName ?? widget.user.email}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoleOption(
              label: 'Employee',
              subtitle: 'Own data only',
              selected: _role == RolePermissions.employee,
              onTap: () => setState(() => _role = RolePermissions.employee),
            ),
            _RoleOption(
              label: 'Director',
              subtitle: 'Manages selected department(s)',
              selected: _role == RolePermissions.manager,
              onTap: () => setState(() => _role = RolePermissions.manager),
            ),
            _RoleOption(
              label: 'Admin',
              subtitle: 'Full access to everything',
              selected: _role == RolePermissions.superAdmin,
              onTap: () => setState(() => _role = RolePermissions.superAdmin),
            ),
            if (isDirector) ...[
              const Divider(),
              const Text('Departments to manage',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted)),
              if (departments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No departments yet — create some first.',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                )
              else
                ...departments.map((d) => CheckboxListTile(
                      value: _depts.contains(d.name),
                      activeColor: AppColors.brandNavy,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _depts.add(d.name);
                        } else {
                          _depts.remove(d.name);
                        }
                      }),
                      title: Text(d.name,
                          style: const TextStyle(
                              fontSize: 13.5, color: AppColors.textBody)),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    )),
            ],
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
          onPressed: () async {
            if (_role == RolePermissions.manager && _depts.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Select at least one department for a Director.')),
              );
              return;
            }
            await ref.read(userAdminServiceProvider).setRole(
                  uid: widget.user.id,
                  role: _role,
                  departments: _depts.toList(),
                  adminId: widget.adminId,
                );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlueSoft : AppColors.canvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.brandNavy : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.brandNavy : AppColors.textFaint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.heading)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
