import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/employee_model.dart';
import '../../../providers/data_providers.dart';

Future<void> showEmployeeSearchDialog(
    BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => const _GlobalSearchDialog(),
  );
}

class _GlobalSearchDialog extends ConsumerStatefulWidget {
  const _GlobalSearchDialog();

  @override
  ConsumerState<_GlobalSearchDialog> createState() =>
      _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<_GlobalSearchDialog> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() => _query = val.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = (screenW * 0.9).clamp(340.0, 620.0);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SizedBox(
        width: dialogW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText:
                      'Search by name, email, phone, CNIC, department...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textFaint,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.brandBlue, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Results
            SizedBox(
              height: 380,
              child: employees.when(
                data: (list) {
                  final filtered = _filter(list, _query);
                  if (_query.isEmpty) {
                    return _hint('Type to search across all employees');
                  }
                  if (filtered.isEmpty) {
                    return _hint('No employees match "$_query"');
                  }
                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (_, i) {
                      final emp = filtered[i];
                      final matchField = _matchedField(emp, _query);
                      return _ResultTile(
                        emp: emp,
                        matchField: matchField,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/employees/${emp.id}');
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Icon(Icons.keyboard_rounded,
                      size: 14, color: AppColors.textFaint),
                  const SizedBox(width: 6),
                  Text(
                    'Type to search · Click to open 360° profile',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textFaint),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded,
                size: 48, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  List<EmployeeModel> _filter(List<EmployeeModel> list, String q) {
    if (q.isEmpty) return [];
    return list.where((e) {
      final hay = [
        e.fullName,
        e.email,
        e.phone ?? '',
        e.cnic ?? '',
        e.departmentName ?? '',
        e.position ?? '',
        e.fatherName ?? '',
        e.address ?? '',
        e.id,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).take(50).toList();
  }

  String? _matchedField(EmployeeModel e, String q) {
    if (q.isEmpty) return null;
    if (e.fullName.toLowerCase().contains(q)) return null;
    if (e.email.toLowerCase().contains(q)) {
      return 'Email: ${e.email}';
    }
    if ((e.phone ?? '').toLowerCase().contains(q)) {
      return 'Phone: ${e.phone}';
    }
    if ((e.cnic ?? '').toLowerCase().contains(q)) {
      return 'CNIC: ${e.cnic}';
    }
    if ((e.departmentName ?? '').toLowerCase().contains(q)) {
      return 'Dept: ${e.departmentName}';
    }
    if ((e.position ?? '').toLowerCase().contains(q)) {
      return 'Designation: ${e.position}';
    }
    if ((e.fatherName ?? '').toLowerCase().contains(q)) {
      return 'Father: ${e.fatherName}';
    }
    if ((e.address ?? '').toLowerCase().contains(q)) {
      return 'Address: ${e.address}';
    }
    return null;
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.emp,
    required this.matchField,
    required this.onTap,
  });
  final EmployeeModel emp;
  final String? matchField;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              InitialAvatar(name: emp.fullName, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.heading)),
                    const SizedBox(height: 2),
                    Text(
                      '${emp.position ?? '—'} · ${emp.departmentName ?? 'No dept'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    if (matchField != null) ...[
                      const SizedBox(height: 2),
                      Text(matchField!,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.brandBlue,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              _statusDot(emp.status),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot(EmployeeStatus s) {
    final color = s == EmployeeStatus.active
        ? AppColors.success
        : s == EmployeeStatus.pending
            ? AppColors.warning
            : AppColors.error;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
