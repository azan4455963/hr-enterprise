import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/service_providers.dart';

/// The signed-in user's own profile: edit name + photo, change password (via a
/// reset email), see account info, and sign out. Available to every role.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _loaded = false;
  bool _savingName = false;
  bool _uploadingPhoto = false;
  bool _sendingReset = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_loaded) {
      _nameCtrl.text = user.displayName ?? '';
      _loaded = true;
    }
    final fmt = DateFormat('dd MMM yyyy');
    final hasPassword = ref.read(authServiceProvider).hasPasswordProvider;
    final photoUrl = user.photoUrl;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeading(
                  title: 'My Profile', subtitle: 'Your account details.'),
              const SizedBox(height: 18),

              // Header
              AppCard(
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        (photoUrl != null && photoUrl.isNotEmpty)
                            ? CircleAvatar(
                                radius: 34,
                                backgroundImage: NetworkImage(photoUrl))
                            : InitialAvatar(
                                name: user.displayName ?? user.email, size: 68),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color: AppColors.brandNavy,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _uploadingPhoto ? null : _pickPhoto,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.camera_alt_rounded,
                                        size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName ?? user.email,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: AppColors.heading)),
                          const SizedBox(height: 2),
                          Text(user.email,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brandNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              RolePermissions.roleLabel(user.role),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandNavy),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Edit profile
              _card(
                'Edit Profile',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: _savingName ? 'Saving…' : 'Save name',
                      icon: Icons.check_rounded,
                      onPressed: _savingName ? () {} : _saveName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Security
              _card(
                'Security',
                hasPassword
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send a password reset link to ${user.email}.',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _sendingReset ? null : _sendReset,
                            icon: const Icon(Icons.lock_reset_rounded, size: 18),
                            label: Text(_sendingReset
                                ? 'Sending…'
                                : 'Send password reset link'),
                          ),
                        ],
                      )
                    : const Row(
                        children: [
                          Icon(Icons.g_mobiledata_rounded,
                              color: AppColors.textMuted),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'You signed in with Google — no password to change.',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Account info
              _card(
                'Account',
                Column(
                  children: [
                    _kv('Role', RolePermissions.roleLabel(user.role)),
                    _kv('Email', user.email),
                    if (user.departmentName?.isNotEmpty ?? false)
                      _kv('Department', user.departmentName!),
                    _kv(
                        'Member since',
                        user.createdAt != null
                            ? fmt.format(user.createdAt!)
                            : '—'),
                    _kv(
                        'Last login',
                        user.lastLoginAt != null
                            ? fmt.format(user.lastLoginAt!)
                            : '—'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, Widget child) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.heading)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody)),
            ),
          ],
        ),
      );

  Future<void> _saveName() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingName = true);
    try {
      await ref
          .read(authServiceProvider)
          .updateMyProfile(displayName: _nameCtrl.text.trim());
      messenger.showSnackBar(const SnackBar(content: Text('Name updated')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _pickPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await ref
          .read(storageServiceProvider)
          .uploadProfilePhoto(user.id, bytes);
      await ref.read(authServiceProvider).updateMyProfile(photoUrl: url);
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _sendReset() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() => _sendingReset = true);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(user.email);
      messenger.showSnackBar(
          SnackBar(content: Text('Reset link sent to ${user.email}')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  Future<void> _signOut() async {
    ref.read(skipBiometricOnLoginProvider.notifier).state = true;
    try {
      await ref.read(authServiceProvider).signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }
}
