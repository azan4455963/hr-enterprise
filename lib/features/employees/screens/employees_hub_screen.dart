import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/export_menu.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';
import 'employee_record_screen.dart';
import 'employee_search_screen.dart';
import 'employees_screen.dart';

/// One "Employees" menu that holds the three employee views as tabs:
/// All Employees, Find, and Record. Same screens — just organised under a
/// single nav item instead of three.
class EmployeesHubScreen extends StatefulWidget {
  const EmployeesHubScreen({super.key});

  @override
  State<EmployeesHubScreen> createState() => _EmployeesHubScreenState();
}

class _EmployeesHubScreenState extends State<EmployeesHubScreen> {
  int _tab = 0;

  static const _labels = ['All Employees', 'Find', 'Record'];
  static const _icons = [
    Icons.people_alt_rounded,
    Icons.person_search_rounded,
    Icons.fact_check_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.canvas,
          padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, 16, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _labels.length; i++) _pill(i)
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _EmployeesExportButton(),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              EmployeesScreen(),
              EmployeeSearchScreen(),
              EmployeeRecordScreen(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(int i) {
    final selected = _tab == i;
    return InkWell(
      onTap: () => setState(() => _tab = i),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandNavy : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.brandNavy : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[i],
                size: 17,
                color: selected ? Colors.white : AppColors.textBody),
            const SizedBox(width: 7),
            Text(
              _labels[i],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Export the full employee list (PDF / Excel) straight from the hub header —
/// mirrors the Reports page "Employees" card. Salary is included only when the
/// signed-in user is allowed to see it.
class _EmployeesExportButton extends ConsumerWidget {
  const _EmployeesExportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);
    return PermissionGate(
      permission: 'reports_export',
      child: ExportMenuButton(
        onExportPdf: () async {
          final data = await ref.read(employeesProvider.future);
          await ref
              .read(exportServiceProvider)
              .shareEmployeesPdf(data, includeSalary: canViewSalary);
        },
        onExportExcel: () async {
          final data = await ref.read(employeesProvider.future);
          final bytes = await ref
              .read(exportServiceProvider)
              .buildEmployeesExcel(data, includeSalary: canViewSalary);
          await saveXlsxBytes(bytes, 'employees.xlsx');
        },
      ),
    );
  }
}
