import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/error_state.dart';
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
  int _dayStartHour = 0;
  List<WorkShift> _shifts = [];
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
    _dayStartHour = s.attendanceDayStartHour;
    _shifts = [...s.shifts];
  }

  static String _fmtTime(int h, int m) {
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  void _addShift() => _shiftDialog();
  void _editShift(int i) => _shiftDialog(existing: _shifts[i], index: i);

  Future<void> _shiftDialog({WorkShift? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var start = TimeOfDay(
        hour: existing?.startHour ?? 9, minute: existing?.startMinute ?? 0);
    var end = TimeOfDay(
        hour: existing?.endHour ?? 17, minute: existing?.endMinute ?? 0);

    final result = await showDialog<WorkShift>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add Shift' : 'Edit Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Shift name', hintText: 'e.g. Day, Night'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start time'),
                trailing: Text(_fmtTime(start.hour, start.minute)),
                onTap: () async {
                  final t =
                      await showTimePicker(context: ctx, initialTime: start);
                  if (t != null) setLocal(() => start = t);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End time'),
                trailing: Text(_fmtTime(end.hour, end.minute)),
                onTap: () async {
                  final t =
                      await showTimePicker(context: ctx, initialTime: end);
                  if (t != null) setLocal(() => end = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  ctx,
                  WorkShift(
                    name: name,
                    startHour: start.hour,
                    startMinute: start.minute,
                    endHour: end.hour,
                    endMinute: end.minute,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _shifts[index] = result;
      } else {
        _shifts = [..._shifts, result];
      }
    });
  }

  static String _fmtHour(int h) {
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:00 $period';
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
              attendanceDayStartHour: _dayStartHour,
              shifts: _shifts,
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

  /// A titled settings card with an icon header and optional subtitle/trailing.
  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 19, color: AppColors.brandNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.heading),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// A labelled slider row with the current value shown on the right.
  Widget _sliderRow(String label, String value, Widget slider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, color: AppColors.textBody)),
            ),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.brandNavy)),
          ],
        ),
        slider,
      ],
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
                const SizedBox(height: 4),
                const Text('Manage your company preferences.',
                    style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 22),
                _section(
                  icon: Icons.tune_rounded,
                  title: 'Appearance & Security',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
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
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Biometric Login'),
                            subtitle: Text(enabled
                                ? 'Enabled'
                                : 'Use fingerprint / face to sign in'),
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
                  _section(
                    icon: Icons.business_rounded,
                    title: 'Company',
                    child: TextField(
                      controller: _companyName,
                      decoration: const InputDecoration(
                        labelText: 'Company Name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    icon: Icons.schedule_rounded,
                    title: 'Work Hours',
                    child: Column(
                      children: [
                        _sliderRow(
                          'Work start',
                          _fmtHour(_startHour),
                          Slider(
                            value: _startHour.toDouble(),
                            min: 6,
                            max: 12,
                            divisions: 6,
                            label: _fmtHour(_startHour),
                            onChanged: (v) =>
                                setState(() => _startHour = v.round()),
                          ),
                        ),
                        _sliderRow(
                          'Late after',
                          '$_lateMin min',
                          Slider(
                            value: _lateMin.toDouble(),
                            min: 0,
                            max: 60,
                            divisions: 12,
                            label: '$_lateMin',
                            onChanged: (v) =>
                                setState(() => _lateMin = v.round()),
                          ),
                        ),
                        _sliderRow(
                          'Work end',
                          _fmtHour(_endHour),
                          Slider(
                            value: _endHour.toDouble(),
                            min: 14,
                            max: 22,
                            divisions: 8,
                            label: _fmtHour(_endHour),
                            onChanged: (v) =>
                                setState(() => _endHour = v.round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    icon: Icons.work_history_rounded,
                    title: 'Work Shifts',
                    subtitle:
                        'Add shifts (name + time). The attendance day rolls '
                        'over at the earliest shift start — so night shifts '
                        'that cross midnight stay in one day.',
                    trailing: TextButton.icon(
                      onPressed: _addShift,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Shift'),
                    ),
                    child: Column(
                      children: [
                        if (_shifts.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No shifts yet.',
                                  style:
                                      TextStyle(color: AppColors.textMuted)),
                            ),
                          )
                        else
                          for (var i = 0; i < _shifts.length; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AppColors.cardBorder),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.schedule_rounded,
                                    size: 20, color: AppColors.brandNavy),
                                title: Text(_shifts[i].name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${_fmtTime(_shifts[i].startHour, _shifts[i].startMinute)} – '
                                    '${_fmtTime(_shifts[i].endHour, _shifts[i].endMinute)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () => _editShift(i),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.error),
                                      onPressed: () => setState(
                                          () => _shifts.removeAt(i)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        if (_shifts.isEmpty) ...[
                          const SizedBox(height: 8),
                          _sliderRow(
                            'Day rollover',
                            _fmtHour(_dayStartHour),
                            Slider(
                              value: _dayStartHour.toDouble(),
                              min: 0,
                              max: 23,
                              divisions: 23,
                              label: _fmtHour(_dayStartHour),
                              onChanged: (v) =>
                                  setState(() => _dayStartHour = v.round()),
                            ),
                          ),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Used only when no shifts are defined. '
                              '12 AM = normal.',
                              style: TextStyle(
                                  fontSize: 11.5, color: AppColors.textFaint),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    icon: Icons.beach_access_rounded,
                    title: 'Leave Allowances',
                    subtitle:
                        'Days per year per type. A balance = this minus leave '
                        'taken this year. Set 0 to not track a type.',
                    child: Row(
                      children: [
                        Expanded(
                            child: _allowanceField('Annual', _annualAllow)),
                        const SizedBox(width: 10),
                        Expanded(child: _allowanceField('Sick', _sickAllow)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _allowanceField('Casual', _casualAllow)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Saving…' : 'Save Settings'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(error: e),
      ),
    );
  }
}
