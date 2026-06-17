import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

/// Full employee report as a viewable, downloadable PDF.
/// Reached from the employee profile. Compiles profile + attendance + leave +
/// payroll into one document with built-in print/share/download.
class EmployeeReportScreen extends ConsumerWidget {
  const EmployeeReportScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(employeeByIdProvider(employeeId));
    final attendance =
        ref.watch(employeeAttendanceHistoryProvider(employeeId)).valueOrNull ??
            [];
    final leaves =
        ref.watch(employeeLeaveHistoryProvider(employeeId)).valueOrNull ?? [];
    final payroll =
        ref.watch(employeePayrollHistoryProvider(employeeId)).valueOrNull ?? [];
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canViewSalary =
        user != null && ref.watch(rbacServiceProvider).canViewSalary(user);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.heading),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/employees/$employeeId'),
        ),
        title: const Text('Employee Report',
            style: TextStyle(
                color: AppColors.heading, fontWeight: FontWeight.w700)),
      ),
      body: empAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (emp) {
          if (emp == null) {
            return const Center(child: Text('Employee not found'));
          }
          final export = ref.read(exportServiceProvider);
          return PdfPreview(
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName:
                '${emp.fullName.replaceAll(' ', '_')}_report.pdf',
            build: (format) => export.buildEmployeeProfilePdf(
              employee: emp,
              attendance: attendance,
              leaves: leaves,
              payroll: payroll,
              includeSalary: canViewSalary,
            ),
          );
        },
      ),
    );
  }
}
