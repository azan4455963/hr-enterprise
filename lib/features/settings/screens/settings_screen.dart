import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/company_settings_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _companyName = TextEditingController();
  final _annualAllow = TextEditingController();
  final _sickAllow = TextEditingController();
  final _casualAllow = TextEditingController();
  int _startHour = 9;
  int _startMin = 0;
  int _lateMin = 15;
  int _endHour = 18;
  int _endMin = 0;
  bool _saving = false;

  @override
  void dispose() {
    _companyName.dispose();
    _annualAllow.dispose();
    _sickAllow.dispose();
    _casualAllow.dispose();
    super.dispose();
  }

  void _load(CompanySettingsModel s) {
    _companyName.text = s.companyName;
    _annualAllow.text = (s.allowanceForName('annual')).toString();
    _sickAllow.text = (s.allowanceForName('sick')).toString();
    _casualAllow.text = (s.allowanceForName('casual')).toString();
    _startHour = s.workStartHour;
    _startMin = s.workStartMinute;
    _lateMin = s.lateAfterMinutes;
    _endHour = s.workEndHour;
    _endMin = s.workEndMinute;
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final current = await ref.read(companySettingsProvider.future);
      int allow(TextEditingController c, String key) =>
          int.tryParse(c.text.trim()) ?? current.allowanceForName(key);
      await ref.read(companySettingsServiceProvider).updateSettings(
            CompanySettingsModel(
              id: current.id,
              companyName: _companyName.text.trim(),
              workStartHour: _startHour,
              workStartMinute: _startMin,
              lateAfterMinutes: _lateMin,
              workEndHour: _endHour,
              workEndMinute: _endMin,
              biometricEnabled: current.biometricEnabled,
              leaveAllowances: {
                'annual': allow(_annualAllow, 'annual'),
                'sick': allow(_sickAllow, 'sick'),
                'casual': allow(_casualAllow, 'casual'),
              },
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    final bio = ref.read(biometricServiceProvider);
    try {
      if (enable) {
        final supported = await bio.isDeviceSupported();
        if (!supported) throw AppException('Biometric not available on this device');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in once with email/password, then enable biometric in Settings after login.'),
          ),
        );
      } else {
        await bio.disable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric login disabled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }

  Future<void> _enableBiometricAfterLogin() async {
    final email = ref.read(currentUserProvider).valueOrNull?.email;
    if (email == null) return;
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Confirm Password'),
          content: TextField(
            controller: c,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
    if (password == null || password.isEmpty) return;
    try {
      await ref.read(biometricServiceProvider).enable(
            email: email,
            password: password,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login enabled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }

  Widget _allowanceField(String label, TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(companySettingsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canEdit = user?.hasPermission('settings_edit') ?? false;

    return Scaffold(
      body: settings.when(
        data: (s) {
          if (_companyName.text.isEmpty) _load(s);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Dark Mode'),
                        value: themeMode == ThemeMode.dark,
                        onChanged: (_) =>
                            ref.read(themeModeProvider.notifier).toggle(),
                      ),
                      FutureBuilder(
                        future: ref.read(biometricServiceProvider).isEnabled(),
                        builder: (_, snap) {
                          final enabled = snap.data ?? false;
                          return SwitchListTile(
                            title: const Text('Biometric Login'),
                            subtitle: Text(enabled ? 'Enabled' : 'Use fingerprint / face to sign in'),
                            value: enabled,
                            onChanged: (v) {
                              if (v) {
                                _enableBiometricAfterLogin();
                              } else {
                                _toggleBiometric(false);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Settings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _companyName,
                          decoration: const InputDecoration(labelText: 'Company Name'),
                        ),
                        const SizedBox(height: 8),
                        Text('Work start: $_startHour:${_startMin.toString().padLeft(2, '0')}'),
                        Slider(
                          value: _startHour.toDouble(),
                          min: 6,
                          max: 12,
                          divisions: 6,
                          label: '$_startHour',
                          onChanged: (v) => setState(() => _startHour = v.round()),
                        ),
                        Text('Late after: $_lateMin minutes'),
                        Slider(
                          value: _lateMin.toDouble(),
                          min: 0,
                          max: 60,
                          divisions: 12,
                          label: '$_lateMin',
                          onChanged: (v) => setState(() => _lateMin = v.round()),
                        ),
                        Text('Work end: $_endHour:${_endMin.toString().padLeft(2, '0')}'),
                        Slider(
                          value: _endHour.toDouble(),
                          min: 14,
                          max: 22,
                          divisions: 8,
                          label: '$_endHour',
                          onChanged: (v) => setState(() => _endHour = v.round()),
                        ),
                        const Divider(height: 28),
                        Text(
                          'Leave Allowances (days per year)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Each employee\'s remaining balance is this minus the '
                          'leave they\'ve taken this year. Set 0 to not track a type.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _allowanceField('Annual', _annualAllow)),
                            const SizedBox(width: 10),
                            Expanded(child: _allowanceField('Sick', _sickAllow)),
                            const SizedBox(width: 10),
                            Expanded(child: _allowanceField('Casual', _casualAllow)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saving ? null : _saveSettings,
                          child: _saving
                              ? const CircularProgressIndicator()
                              : const Text('Save Company Settings'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
