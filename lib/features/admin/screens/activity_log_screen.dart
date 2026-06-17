import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/audit_log_model.dart';
import '../../../providers/data_providers.dart';

/// Admin-only: a full audit trail — who did what, when. Filter by person and
/// by area (employees / attendance / leave / users / departments…).
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

const _allModules = 'All areas';
const _allUsers = 'All users';

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  String _module = _allModules;
  String _userId = _allUsers;

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final logsAsync = ref.watch(allAuditLogsProvider);
    final users = ref.watch(usersProvider).valueOrNull ?? [];

    // uid -> display label for "who did it".
    final nameByUid = {
      for (final u in users) u.id: (u.displayName ?? u.email),
    };

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Activity Log',
            subtitle: 'Who did what, and when. Admin only.',
          ),
          const SizedBox(height: 18),
          logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: AppColors.error)),
            data: (logs) {
              final modules = <String>{for (final l in logs) l.module}.toList()
                ..sort();
              // Apply filters.
              var filtered = logs.where((l) {
                if (_module != _allModules && l.module != _module) return false;
                if (_userId != _allUsers && l.userId != _userId) return false;
                return true;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FilterDropdown(
                        icon: Icons.category_outlined,
                        value: _module,
                        items: [_allModules, ...modules],
                        onChanged: (v) => setState(() => _module = v),
                      ),
                      _FilterDropdown(
                        icon: Icons.person_outline,
                        value: _userId,
                        items: [_allUsers, ...nameByUid.keys],
                        labelFor: (id) =>
                            id == _allUsers ? _allUsers : (nameByUid[id] ?? id),
                        onChanged: (v) => setState(() => _userId = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No activity yet',
                                style: TextStyle(color: AppColors.textMuted)),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                _LogRow(
                                  log: filtered[i],
                                  who: nameByUid[filtered[i].userId] ??
                                      'Unknown user',
                                ),
                                if (i != filtered.length - 1)
                                  const Divider(
                                      height: 16, color: AppColors.cardBorder),
                              ],
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.who});
  final AuditLogModel log;
  final String who;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
                color: _color(log.module), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: who,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.heading),
                      ),
                      TextSpan(
                        text: '  ${_describe(log)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textBody),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.module} · ${_timeAgo(log.createdAt)}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _describe(AuditLogModel log) {
    final d = log.details ?? const {};
    // Special, more descriptive cases first.
    if (log.module == 'users') {
      if (d['role'] != null) return 'set role to "${d['role']}"';
      if (d['isActive'] != null) {
        return d['isActive'] == true ? 'enabled an account' : 'disabled an account';
      }
    }
    if (log.module == 'departments') {
      if (d['assignedDirector'] != null) return 'assigned a director';
      if (d['removedDirector'] != null) return 'removed a director';
      if (d['name'] != null) return 'set department "${d['name']}"';
    }
    switch (log.action) {
      case 'create':
        return 'created a ${log.module} record';
      case 'update':
        return 'updated ${log.module}';
      case 'delete':
        return 'deleted a ${log.module} record';
      case 'approve':
        return 'approved a ${log.module} request';
      case 'reject':
        return 'rejected a ${log.module} request';
      case 'login':
        return 'signed in';
      case 'logout':
        return 'signed out';
      default:
        return '${log.action} · ${log.module}';
    }
  }

  static Color _color(String module) {
    switch (module) {
      case 'attendance':
        return AppColors.pillGreenFg;
      case 'leave':
        return AppColors.brandBlue;
      case 'payroll':
        return AppColors.pillAmberFg;
      case 'users':
      case 'departments':
        return AppColors.primary;
      case 'auth':
        return AppColors.accent;
      default:
        return AppColors.pillRedFg;
    }
  }

  static String _timeAgo(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return DateFormat('dd MMM yyyy, hh:mm a').format(at);
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelFor,
  });
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String Function(String)? labelFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 16, color: AppColors.textMuted),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody),
              items: [
                for (final it in items)
                  DropdownMenuItem(
                      value: it,
                      child: Text(labelFor != null ? labelFor!(it) : it)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
