import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/export_menu.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;

  Future<void> _runExport(Future<void> Function() action) async {
    setState(() => _exporting = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    final cards = <Widget>[
      _ReportCard(
        title: 'Attendance',
        subtitle: 'Daily logs, last 30 days.',
        icon: Icons.access_time_rounded,
        accent: AppColors.brandBlue,
        accentBg: AppColors.brandBlueSoft,
        onPdf: () => _runExport(() async {
          final data = await ref
              .read(attendanceServiceProvider)
              .fetchForExport(days: 30);
          await ref.read(exportServiceProvider).shareAttendancePdf(data);
        }),
        onExcel: () => _runExport(() async {
          final data = await ref
              .read(attendanceServiceProvider)
              .fetchForExport(days: 30);
          final bytes =
              await ref.read(exportServiceProvider).buildAttendanceExcel(data);
          await saveXlsxBytes(bytes, 'attendance.xlsx');
        }),
      ),
      _ReportCard(
        title: 'Employees',
        subtitle: 'Full staff directory.',
        icon: Icons.groups_rounded,
        accent: AppColors.pillBlueFg,
        accentBg: AppColors.pillBlueBg,
        onPdf: () => _runExport(() async {
          final data = await ref.read(employeesProvider.future);
          await ref
              .read(exportServiceProvider)
              .shareEmployeesPdf(data, includeSalary: canViewSalary);
        }),
        onExcel: () => _runExport(() async {
          final data = await ref.read(employeesProvider.future);
          final bytes = await ref
              .read(exportServiceProvider)
              .buildEmployeesExcel(data, includeSalary: canViewSalary);
          await saveXlsxBytes(bytes, 'employees.xlsx');
        }),
      ),
      _ReportCard(
        title: 'Payroll',
        subtitle: 'Salary records & status.',
        icon: Icons.payments_rounded,
        accent: AppColors.pillGreenFg,
        accentBg: AppColors.pillGreenBg,
        onPdf: () => _runExport(() async {
          final data = await ref.read(payrollProvider.future);
          await ref.read(exportServiceProvider).sharePayrollPdf(data);
        }),
        onExcel: () => _runExport(() async {
          final data = await ref.read(payrollProvider.future);
          final bytes =
              await ref.read(exportServiceProvider).buildPayrollExcel(data);
          await saveXlsxBytes(bytes, 'payroll.xlsx');
        }),
      ),
      _ReportCard(
        title: 'Leave',
        subtitle: 'Requests & balances.',
        icon: Icons.beach_access_rounded,
        accent: AppColors.pillAmberFg,
        accentBg: AppColors.pillAmberBg,
        onPdf: () => _runExport(() async {
          final data = await ref.read(leaveRequestsProvider.future);
          await ref.read(exportServiceProvider).shareLeavePdf(data);
        }),
        onExcel: () => _runExport(() async {
          final data = await ref.read(leaveRequestsProvider.future);
          final bytes =
              await ref.read(exportServiceProvider).buildLeaveExcel(data);
          await saveXlsxBytes(bytes, 'leave.xlsx');
        }),
      ),
    ];

    return PermissionGate(
      permission: 'reports_view',
      fallback: const Scaffold(
        body: Center(child: Text('No permission to view reports')),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(isWide ? 28 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeading(
                    title: 'Reports & Export',
                    subtitle:
                        'Download attendance, employees, payroll and leave data.',
                  ),
                  const SizedBox(height: 22),
                  _Grid(isWide: isWide, cards: cards),
                ],
              ),
            ),
            if (_exporting)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lays the report cards out 2-up on wide screens, stacked on narrow.
class _Grid extends StatelessWidget {
  const _Grid({required this.isWide, required this.cards});

  final bool isWide;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            cards[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cards[i]),
          const SizedBox(width: 16),
          if (i + 1 < cards.length)
            Expanded(child: cards[i + 1])
          else
            const Expanded(child: SizedBox.shrink()),
        ],
      ));
      if (i + 2 < cards.length) rows.add(const SizedBox(height: 16));
    }
    return Column(children: rows);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.onExcel,
    this.onPdf,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final VoidCallback? onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.heading)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PermissionGate(
            permission: 'reports_export',
            child: Row(
              children: [
                if (onPdf != null) ...[
                  Expanded(
                    child: _ExportBtn(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      color: AppColors.pillRedFg,
                      onTap: onPdf!,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _ExportBtn(
                    label: 'Excel',
                    icon: Icons.table_chart_outlined,
                    color: AppColors.pillGreenFg,
                    onTap: onExcel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportBtn extends StatelessWidget {
  const _ExportBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
