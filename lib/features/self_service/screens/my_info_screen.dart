import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/notification_model.dart';
import '../../../models/onboarding_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

/// A signed-in user fills in their own HR details. The submission goes to the
/// admin's onboarding review queue; once approved, an employee record is created
/// and linked back to this account (by email). No salary here — admins set that.
class MyInfoScreen extends ConsumerStatefulWidget {
  const MyInfoScreen({super.key});

  @override
  ConsumerState<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends ConsumerState<MyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _father = TextEditingController();
  final _cnic = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _position = TextEditingController();
  String? _department;
  bool _loaded = false;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _father.dispose();
    _cnic.dispose();
    _phone.dispose();
    _address.dispose();
    _position.dispose();
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
      final parts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
      _first.text = parts.isNotEmpty ? parts.first : '';
      _last.text = parts.length > 1 ? parts.skip(1).join(' ') : '';
      _loaded = true;
    }
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];
    final alreadyLinked =
        user.employeeId != null && user.employeeId!.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeading(
                title: 'My Information',
                subtitle: 'Add your details for HR. An admin will review them.',
              ),
              const SizedBox(height: 18),
              if (alreadyLinked)
                const AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "You're already set up as an employee — your profile "
                          'is linked. Contact an admin to change your details.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_done)
                _SubmittedCard(onDone: () => context.go('/profile'))
              else
                AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your details are reviewed by an admin before they go '
                          'live. Salary is set by HR, not here.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _field(_first, 'First name',
                                    required: true)),
                            const SizedBox(width: 12),
                            Expanded(
                                child:
                                    _field(_last, 'Last name', required: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _readonly('Email', user.email),
                        const SizedBox(height: 12),
                        _field(_father, "Father's name"),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _field(_cnic, 'CNIC / ID')),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _field(_phone, 'Phone',
                                    required: true,
                                    keyboard: TextInputType.phone)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _department,
                          isExpanded: true,
                          decoration: _dec('Department', required: true),
                          items: [
                            for (final d in departments)
                              DropdownMenuItem(
                                  value: d.name, child: Text(d.name)),
                          ],
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _department = v),
                        ),
                        const SizedBox(height: 12),
                        _field(_position, 'Designation / role'),
                        const SizedBox(height: 12),
                        _field(_address, 'Address', maxLines: 2),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: _saving ? 'Submitting…' : 'Submit for approval',
                            icon: Icons.send_rounded,
                            onPressed: _saving ? () {} : () => _submit(user.email),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, {bool required = false}) => InputDecoration(
        labelText: required ? '$label *' : label,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  Widget _field(TextEditingController c, String label,
      {bool required = false,
      int maxLines = 1,
      TextInputType? keyboard}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      enabled: !_saving,
      decoration: _dec(label, required: required),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Widget _readonly(String label, String value) => InputDecorator(
        decoration: _dec(label).copyWith(
          suffixIcon: const Icon(Icons.lock_outline, size: 16),
        ),
        child: Text(value,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textBody)),
      );

  Future<void> _submit(String email) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(onboardingServiceProvider).selfSubmit(
            OnboardingSubmissionModel(
              id: '',
              linkId: 'self',
              firstName: _first.text.trim(),
              lastName: _last.text.trim(),
              fatherName: _emptyToNull(_father.text),
              cnic: _emptyToNull(_cnic.text),
              phone: _emptyToNull(_phone.text),
              email: email,
              address: _emptyToNull(_address.text),
              department: _department,
              position: _emptyToNull(_position.text),
            ),
          );
      await ref.read(messagingServiceProvider).notifyRole(
            title: 'New employee info submitted',
            body:
                '${_first.text.trim()} ${_last.text.trim()} submitted their details for approval.',
            type: NotificationType.system,
            targetRoles: [RolePermissions.superAdmin],
          );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();
}

class _SubmittedCard extends StatelessWidget {
  const _SubmittedCard({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.task_alt_rounded,
              size: 46, color: AppColors.success),
          const SizedBox(height: 12),
          const Text('Submitted for approval',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.heading)),
          const SizedBox(height: 6),
          const Text(
            'An admin will review your details. Once approved, your profile '
            'will be linked and your leave, attendance and salary will show up '
            'in My Space.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Done', onPressed: onDone),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
