import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
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

  Future<void> _shareExcel(Uint8List bytes, String filename) async {
    await saveBytes(
      bytes,
      filename,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    return PermissionGate(
      permission: 'reports_view',
      fallback: const Scaffold(
        body: Center(child: Text('No permission to view reports')),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports & Export',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: [
                        _ReportCard(
                          title: 'Attendance',
                          icon: Icons.access_time,
                          onPdf: () => _runExport(() async {
                            final data = await ref
                                .read(attendanceServiceProvider)
                                .fetchForExport(days: 30);
                            await ref
                                .read(exportServiceProvider)
                                .shareAttendancePdf(data);
                          }),
                          onExcel: () => _runExport(() async {
                            final data = await ref
                                .read(attendanceServiceProvider)
                                .fetchForExport(days: 30);
                            final bytes = await ref
                                .read(exportServiceProvider)
                                .buildAttendanceExcel(data);
                            await _shareExcel(bytes, 'attendance.xlsx');
                          }),
                        ),
                        _ReportCard(
                          title: 'Employees',
                          icon: Icons.people,
                          onPdf: () => _runExport(() async {
                            final data =
                                await ref.read(employeesProvider.future);
                            await ref.read(exportServiceProvider).shareEmployeesPdf(
                                  data,
                                  includeSalary: canViewSalary,
                                );
                          }),
                          onExcel: () => _runExport(() async {
                            final data =
                                await ref.read(employeesProvider.future);
                            final bytes = await ref
                                .read(exportServiceProvider)
                                .buildEmployeesExcel(
                                  data,
                                  includeSalary: canViewSalary,
                                );
                            await _shareExcel(bytes, 'employees.xlsx');
                          }),
                        ),
                        _ReportCard(
                          title: 'Payroll',
                          icon: Icons.payments,
                          onPdf: () => _runExport(() async {
                            final data =
                                await ref.read(payrollProvider.future);
                            await ref
                                .read(exportServiceProvider)
                                .sharePayrollPdf(data);
                          }),
                          onExcel: () => _runExport(() async {
                            final data =
                                await ref.read(payrollProvider.future);
                            final bytes = await ref
                                .read(exportServiceProvider)
                                .buildPayrollExcel(data);
                            await _shareExcel(bytes, 'payroll.xlsx');
                          }),
                        ),
                        _ReportCard(
                          title: 'Leave',
                          icon: Icons.beach_access,
                          onPdf: null,
                          onExcel: () => _runExport(() async {
                            final data =
                                await ref.read(leaveRequestsProvider.future);
                            final bytes = await ref
                                .read(exportServiceProvider)
                                .buildLeaveExcel(data);
                            await _shareExcel(bytes, 'leave.xlsx');
                          }),
                        ),
                      ],
                    ),
                  ),
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.icon,
    required this.onExcel,
    this.onPdf,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (onPdf != null)
            PermissionGate(
              permission: 'reports_export',
              child: OutlinedButton.icon(
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF'),
              ),
            ),
          const SizedBox(height: 8),
          PermissionGate(
            permission: 'reports_export',
            child: OutlinedButton.icon(
              onPressed: onExcel,
              icon: const Icon(Icons.table_chart, size: 18),
              label: const Text('Excel'),
            ),
          ),
        ],
      ),
    );
  }
}
