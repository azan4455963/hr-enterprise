import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (var i = 0; i < _labels.length; i++) _pill(i)],
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
