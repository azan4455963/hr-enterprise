import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/attendance_model.dart';
import '../models/data_table_model.dart';
import '../models/employee_model.dart';
import '../models/leave_model.dart';
import '../models/payroll_model.dart';

class ExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final _dayFormat = DateFormat('dd MMM yyyy');

  /// Export a custom data table as a PDF (landscape for wide tables).
  Future<void> shareTablePdf({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        orientation: pw.PageOrientation.landscape,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: columns,
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle:
                pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            data: rows,
          ),
          pw.SizedBox(height: 16),
          pw.Text('Generated ${_dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${title.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Monthly salary slip for one employee, built from a payroll record.
  Future<Uint8List> buildPayslipPdf({
    required EmployeeModel employee,
    required PayrollModel payroll,
    required String companyName,
  }) async {
    final doc = pw.Document();
    final monthName =
        DateFormat('MMMM yyyy').format(DateTime(payroll.year, payroll.month));
    final earnings = payroll.baseSalary + payroll.overtime + payroll.bonuses;

    pw.Widget money(String label, double v, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text('Rs ${NumberFormat('#,##0').format(v)}',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );

    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              color: PdfColors.indigo50,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyName,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('SALARY SLIP — $monthName',
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(employee.fullName,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '${employee.position ?? "-"}  •  ${employee.departmentName ?? "-"}',
                      style:
                          pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Emp ID: ${employee.id.length >= 6 ? employee.id.substring(0, 6).toUpperCase() : employee.id.toUpperCase()}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text('Pay period: $monthName',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('EARNINGS',
                            style: pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        money('Basic Salary', payroll.baseSalary),
                        money('Overtime', payroll.overtime),
                        money('Bonuses', payroll.bonuses),
                        pw.Divider(),
                        money('Total Earnings', earnings, bold: true),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DEDUCTIONS',
                            style: pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        money('Deductions', payroll.deductions),
                        pw.Divider(),
                        money('Total Deductions', payroll.deductions,
                            bold: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                  color: PdfColors.indigo,
                  borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET PAY',
                      style: pw.TextStyle(
                          fontSize: 13,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Rs ${NumberFormat('#,##0').format(payroll.calculatedNet)}',
                      style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Payment status: ${payroll.status.name.toUpperCase()}'
              '${payroll.paidAt != null ? "  •  Paid on ${_dayFormat.format(payroll.paidAt!)}" : ""}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'System-generated payslip. Generated ${_dateFormat.format(DateTime.now())}.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Build + share/print one employee's payslip for a month (web-safe via
  /// printing's share sheet / browser print).
  Future<void> sharePayslipPdf({
    required EmployeeModel employee,
    required PayrollModel payroll,
    required String companyName,
  }) async {
    final bytes = await buildPayslipPdf(
      employee: employee,
      payroll: payroll,
      companyName: companyName,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'payslip_${employee.fullName.replaceAll(' ', '_')}_${payroll.month}-${payroll.year}.pdf',
    );
  }

  /// Generate one salary slip per employee row from a Salary Workbook sheet,
  /// combined into a single PDF. Adapts to whatever columns the sheet has:
  /// each non-empty cell becomes a line (label = column header), the "Net
  /// Salary" column is emphasised, and the "Employee Name" column is the title.
  Future<void> shareSalarySlipsPdf({
    required String companyName,
    required String monthLabel,
    required List<String> columns,
    required List<List<String>> rows,
  }) async {
    final nameIdx =
        columns.indexWhere((c) => c.toLowerCase().contains('name'));
    final netIdx = columns.indexWhere((c) {
      final l = c.toLowerCase();
      return l.contains('net') && (l.contains('salary') || l.contains('pay'));
    });

    final doc = pw.Document();
    var count = 0;
    for (final row in rows) {
      if (!row.any((c) => c.trim().isNotEmpty)) continue;
      final name =
          (nameIdx >= 0 && nameIdx < row.length) ? row[nameIdx].trim() : '';
      if (name.isEmpty) continue;
      count++;
      doc.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(28),
          build: (context) => _salarySlip(
              companyName, monthLabel, columns, row, nameIdx, netIdx, name),
        ),
      );
    }
    if (count == 0) {
      throw Exception(
          'No employee rows found. The sheet needs an "Employee Name" column '
          'with names filled in.');
    }
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'salary_slips_${monthLabel.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _salarySlip(String company, String month, List<String> cols,
      List<String> row, int nameIdx, int netIdx, String name) {
    final lines = <pw.Widget>[];
    for (var i = 0; i < cols.length; i++) {
      if (i == nameIdx) continue;
      final v = (i < row.length ? row[i] : '').trim();
      if (v.isEmpty) continue;
      final isNet = i == netIdx;
      lines.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(cols[i],
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isNet ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: isNet ? PdfColors.indigo : PdfColors.grey800)),
            ),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isNet ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          color: PdfColors.indigo50,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(company,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('SALARY SLIP — $month',
                  style:
                      pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Text(name,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(children: lines),
        ),
        pw.Spacer(),
        pw.Divider(),
        pw.Text('System-generated salary slip. '
            'Generated ${_dateFormat.format(DateTime.now())}.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  /// Self-service "My Report" PDF for an employee — profile, leave summary +
  /// history, and the monthly salary breakdown. Built only from data the
  /// employee can read (no EmployeeModel needed). PDF only, web-safe.
  Future<void> shareMyReportPdf({
    required String companyName,
    required String employeeName,
    required String role,
    String? department,
    String? email,
    required List<LeaveRequestModel> leaves,
    required List<PayrollModel> payroll,
    int attPresent = 0,
    int attLate = 0,
    int attLeave = 0,
    int attAbsent = 0,
    List<({String date, String status})> attendance = const [],
  }) async {
    final doc = pw.Document();
    final totalLeaveDays = leaves
        .where((l) => l.status == LeaveStatus.approved)
        .fold<int>(0, (s, l) => s + l.days);
    final totalNet = payroll.fold<double>(0, (s, p) => s + p.calculatedNet);

    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 140,
                child: pw.Text(k,
                    style:
                        pw.TextStyle(color: PdfColors.grey700, fontSize: 10))),
            pw.Expanded(
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))),
          ]),
        );

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            color: PdfColors.indigo50,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Employee Report',
                    style:
                        pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          kv('Name', employeeName),
          kv('Role', role),
          if (department != null && department.isNotEmpty)
            kv('Department', department),
          if (email != null && email.isNotEmpty) kv('Email', email),
          pw.SizedBox(height: 16),

          if (attPresent + attLate + attLeave + attAbsent > 0 ||
              attendance.isNotEmpty) ...[
            pw.Text('Attendance',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            kv('Present', '$attPresent'),
            kv('Late', '$attLate'),
            kv('Leave', '$attLeave'),
            kv('Absent', '$attAbsent'),
            pw.SizedBox(height: 8),
            if (attendance.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Status'],
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                data: attendance.map((a) => [a.date, a.status]).toList(),
              ),
            pw.SizedBox(height: 16),
          ],

          pw.Text('Leave Summary',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          kv('Total approved leave', '$totalLeaveDays day(s)'),
          kv('Total requests', '${leaves.length}'),
          pw.SizedBox(height: 8),
          if (leaves.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: ['Type', 'From', 'To', 'Days', 'Status'],
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              data: leaves
                  .map((l) => [
                        l.leaveType.name,
                        _dayFormat.format(l.startDate),
                        _dayFormat.format(l.endDate),
                        '${l.days}',
                        l.status.name,
                      ])
                  .toList(),
            ),
          pw.SizedBox(height: 16),

          pw.Text('Salary Record',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          if (payroll.isEmpty)
            pw.Text('No salary records yet.',
                style: const pw.TextStyle(fontSize: 10))
          else ...[
            pw.TableHelper.fromTextArray(
              headers: ['Month', 'Base', 'Bonus', 'Deductions', 'Net', 'Status'],
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              data: payroll
                  .map((p) => [
                        '${p.month}/${p.year}',
                        p.baseSalary.toStringAsFixed(0),
                        p.bonuses.toStringAsFixed(0),
                        p.deductions.toStringAsFixed(0),
                        p.calculatedNet.toStringAsFixed(0),
                        p.status.name,
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Total net (all months): Rs ${NumberFormat('#,##0').format(totalNet)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text('Generated ${_dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'my_report_${employeeName.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Full single-employee profile report: details, attendance, leave & payroll.
  Future<Uint8List> buildEmployeeProfilePdf({
    required EmployeeModel employee,
    required List<AttendanceModel> attendance,
    required List<LeaveRequestModel> leaves,
    required List<PayrollModel> payroll,
    bool includeSalary = true,
  }) async {
    final doc = pw.Document();
    final e = employee;

    String tenure() {
      if (e.joiningDate == null) return '-';
      final months =
          (DateTime.now().difference(e.joiningDate!).inDays / 30).floor();
      if (months < 1) return 'Less than a month';
      if (months < 12) return '$months month(s)';
      final y = months ~/ 12, m = months % 12;
      return m == 0 ? '$y year(s)' : '$y year(s) $m month(s)';
    }

    final presentDays = attendance
        .where((a) =>
            a.status == AttendanceStatus.present ||
            a.status == AttendanceStatus.late)
        .length;
    final leaveDays = leaves
        .where((l) => l.status == LeaveStatus.approved)
        .fold<int>(0, (s, l) => s + l.days);

    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 130,
                child: pw.Text(k,
                    style: pw.TextStyle(
                        color: PdfColors.grey700, fontSize: 10))),
            pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))),
          ]),
        );

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(e.fullName,
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${e.position ?? "-"}  •  ${e.departmentName ?? "-"}  •  ${e.status.name.toUpperCase()}',
                  style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Snapshot
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _statBox('Present Days', '$presentDays'),
              _statBox('Leaves Taken', '$leaveDays'),
              _statBox('Tenure', tenure()),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('Personal Information',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          kv('Full Name', e.fullName),
          kv('Father Name', e.fatherName ?? '-'),
          kv('CNIC', e.cnic ?? '-'),
          kv('Address', e.address ?? '-'),
          kv('Email', e.email),
          kv('Phone', e.phone ?? '-'),
          pw.SizedBox(height: 12),

          pw.Text('Employment',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          kv('Joining Date',
              e.joiningDate != null ? _dayFormat.format(e.joiningDate!) : '-'),
          kv('Leaving Date',
              e.leavingDate != null ? _dayFormat.format(e.leavingDate!) : '-'),
          kv('Currently Active',
              e.status == EmployeeStatus.active ? 'Yes' : 'No'),
          kv('Department', e.departmentName ?? '-'),
          kv('Designation', e.position ?? '-'),
          if (includeSalary)
            kv('Current Salary',
                e.salary != null ? 'Rs ${e.salary!.toStringAsFixed(0)}' : '-'),
          pw.SizedBox(height: 16),

          if (includeSalary && payroll.isNotEmpty) ...[
            pw.Text('Monthly Salary Record',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Month', 'Base', 'Overtime', 'Deductions', 'Net', 'Status'],
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
              data: payroll
                  .map((p) => [
                        '${p.month}/${p.year}',
                        p.baseSalary.toStringAsFixed(0),
                        p.overtime.toStringAsFixed(0),
                        p.deductions.toStringAsFixed(0),
                        p.calculatedNet.toStringAsFixed(0),
                        p.status.name,
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          if (leaves.isNotEmpty) ...[
            pw.Text('Leave Record',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Type', 'From', 'To', 'Days', 'Status'],
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
              data: leaves
                  .map((l) => [
                        l.leaveType.name,
                        _dayFormat.format(l.startDate),
                        _dayFormat.format(l.endDate),
                        '${l.days}',
                        l.status.name,
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          if (attendance.isNotEmpty) ...[
            pw.Text('Attendance Record (recent)',
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Check In', 'Check Out', 'Status'],
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
              data: attendance
                  .take(60)
                  .map((a) => [
                        _dayFormat.format(a.date),
                        a.checkIn != null
                            ? DateFormat('hh:mm a').format(a.checkIn!)
                            : '-',
                        a.checkOut != null
                            ? DateFormat('hh:mm a').format(a.checkOut!)
                            : '-',
                        a.status.name,
                      ])
                  .toList(),
            ),
          ],

          pw.SizedBox(height: 20),
          pw.Text(
            'Generated ${_dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _statBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  Future<void> shareAttendancePdf(List<AttendanceModel> records) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Attendance Report')),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Employee', 'Date', 'Check In', 'Check Out', 'Status', 'Method'],
            data: records
                .map(
                  (r) => [
                    r.employeeName ?? r.employeeId,
                    _dateFormat.format(r.date),
                    r.checkIn != null ? _dateFormat.format(r.checkIn!) : '-',
                    r.checkOut != null ? _dateFormat.format(r.checkOut!) : '-',
                    r.status.name,
                    r.attendanceMethod.name,
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'attendance_report.pdf',
    );
  }

  Future<void> shareEmployeesPdf(List<EmployeeModel> employees, {bool includeSalary = false}) async {
    final doc = pw.Document();
    final headers = [
      'Name',
      'Email',
      'Department',
      'Position',
      'Status',
      if (includeSalary) 'Salary',
    ];
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Employee Report')),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: employees
                .map(
                  (e) => [
                    e.fullName,
                    e.email,
                    e.departmentName ?? '-',
                    e.position ?? '-',
                    e.status.name,
                    if (includeSalary) '${e.salary ?? 0}',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'employee_report.pdf',
    );
  }

  Future<void> sharePayrollPdf(List<PayrollModel> records) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Payroll Report')),
          pw.TableHelper.fromTextArray(
            headers: [
              'Employee',
              'Month',
              'Year',
              'Base',
              'Overtime',
              'Deductions',
              'Net',
              'Status',
            ],
            data: records
                .map(
                  (p) => [
                    p.employeeName,
                    '${p.month}',
                    '${p.year}',
                    '${p.baseSalary}',
                    '${p.overtime}',
                    '${p.deductions}',
                    '${p.calculatedNet}',
                    p.status.name,
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'payroll_report.pdf',
    );
  }

  Future<void> shareLeavePdf(List<LeaveRequestModel> records) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Leave Report')),
          pw.TableHelper.fromTextArray(
            headers: [
              'Employee',
              'Type',
              'Start',
              'End',
              'Days',
              'Status',
              'Reason',
            ],
            data: records
                .map(
                  (r) => [
                    r.employeeName,
                    r.leaveType.name,
                    _dateFormat.format(r.startDate),
                    _dateFormat.format(r.endDate),
                    '${r.days}',
                    r.status.name,
                    r.reason ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'leave_report.pdf',
    );
  }

  Future<Uint8List> buildAttendanceExcel(List<AttendanceModel> records) async {
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];
    sheet.appendRow([
      TextCellValue('Employee'),
      TextCellValue('Date'),
      TextCellValue('Check In'),
      TextCellValue('Check Out'),
      TextCellValue('Status'),
      TextCellValue('Method'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(r.employeeName ?? r.employeeId),
        TextCellValue(_dateFormat.format(r.date)),
        TextCellValue(r.checkIn != null ? _dateFormat.format(r.checkIn!) : '-'),
        TextCellValue(r.checkOut != null ? _dateFormat.format(r.checkOut!) : '-'),
        TextCellValue(r.status.name),
        TextCellValue(r.attendanceMethod.name),
      ]);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List> buildEmployeesExcel(
    List<EmployeeModel> employees, {
    bool includeSalary = false,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Employees'];
    sheet.appendRow([
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Email'),
      TextCellValue('Phone'),
      TextCellValue('Department'),
      TextCellValue('Position'),
      TextCellValue('Status'),
      if (includeSalary) TextCellValue('Salary'),
    ]);
    for (final e in employees) {
      sheet.appendRow([
        TextCellValue(e.firstName),
        TextCellValue(e.lastName),
        TextCellValue(e.email),
        TextCellValue(e.phone ?? ''),
        TextCellValue(e.departmentName ?? ''),
        TextCellValue(e.position ?? ''),
        TextCellValue(e.status.name),
        if (includeSalary) DoubleCellValue(e.salary ?? 0),
      ]);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List> buildLeaveExcel(List<LeaveRequestModel> records) async {
    final excel = Excel.createExcel();
    final sheet = excel['Leave'];
    sheet.appendRow([
      TextCellValue('Employee'),
      TextCellValue('Type'),
      TextCellValue('Start'),
      TextCellValue('End'),
      TextCellValue('Days'),
      TextCellValue('Status'),
      TextCellValue('Reason'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(r.employeeName),
        TextCellValue(r.leaveType.name),
        TextCellValue(_dateFormat.format(r.startDate)),
        TextCellValue(_dateFormat.format(r.endDate)),
        IntCellValue(r.days),
        TextCellValue(r.status.name),
        TextCellValue(r.reason ?? ''),
      ]);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  /// Export a whole custom table as an .xlsx workbook — one worksheet per tab,
  /// first row = column headers. Cells are written as text (round-trips cleanly
  /// back through import).
  Future<Uint8List> buildTableWorkbookExcel(DataTableModel table) async {
    final excel = Excel.createExcel();
    final used = <String>{};

    String sheetName(String raw, int index) {
      // Excel sheet names: max 31 chars, no [ ] : * ? / \, must be unique.
      var n = raw.replaceAll(RegExp(r'[\[\]\*\?:\\/]'), ' ').trim();
      if (n.isEmpty) n = 'Sheet ${index + 1}';
      if (n.length > 31) n = n.substring(0, 31);
      var candidate = n;
      var k = 1;
      while (used.contains(candidate.toLowerCase())) {
        final suffix = ' (${++k})';
        final base = n.length + suffix.length > 31
            ? n.substring(0, 31 - suffix.length)
            : n;
        candidate = '$base$suffix';
      }
      used.add(candidate.toLowerCase());
      return candidate;
    }

    for (var i = 0; i < table.sheets.length; i++) {
      final s = table.sheets[i];
      final ws = excel[sheetName(s.name, i)];
      if (s.columns.isNotEmpty) {
        ws.appendRow([for (final c in s.columns) TextCellValue(c)]);
      }
      for (final row in s.rows) {
        ws.appendRow([for (final cell in row) TextCellValue(cell)]);
      }
    }

    // Drop the auto-created default sheet if we didn't reuse its name.
    final def = excel.getDefaultSheet();
    if (def != null && !used.contains(def.toLowerCase())) {
      excel.delete(def);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  /// Build a one-sheet .xlsx from a single tab's columns + rows — used by the
  /// in-editor "Export Excel" so each tab can be downloaded on its own.
  Future<Uint8List> buildSheetExcel({
    required String sheetName,
    required List<String> columns,
    required List<List<String>> rows,
  }) async {
    final excel = Excel.createExcel();
    var name = sheetName.replaceAll(RegExp(r'[\[\]\*\?:\\/]'), ' ').trim();
    if (name.isEmpty) name = 'Sheet1';
    if (name.length > 31) name = name.substring(0, 31);
    final ws = excel[name];
    if (columns.isNotEmpty) {
      ws.appendRow([for (final c in columns) TextCellValue(c)]);
    }
    for (final row in rows) {
      ws.appendRow([for (final cell in row) TextCellValue(cell)]);
    }
    final def = excel.getDefaultSheet();
    if (def != null && def.toLowerCase() != name.toLowerCase()) {
      excel.delete(def);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  /// One employee's whole record as an .xlsx workbook: Summary + Attendance +
  /// Salary + Leave sheets. Attendance comes from the custom tables (passed in
  /// as plain rows). Used by the Employee Record (360) screen.
  Future<Uint8List> buildEmployeeRecordExcel({
    required EmployeeModel employee,
    required int presentDays,
    required int lateDays,
    required int leaveDays,
    required int absentDays,
    required List<({String date, String status, String source})> attendance,
    required List<PayrollModel> payroll,
    required List<LeaveRequestModel> leaves,
    bool includeSalary = true,
  }) async {
    final excel = Excel.createExcel();

    final sum = excel['Summary'];
    void kv(String k, CellValue v) =>
        sum.appendRow([TextCellValue(k), v]);
    kv('Name', TextCellValue(employee.fullName));
    kv('Department', TextCellValue(employee.departmentName ?? '-'));
    kv('Designation', TextCellValue(employee.position ?? '-'));
    kv('Email', TextCellValue(employee.email));
    kv('Phone', TextCellValue(employee.phone ?? '-'));
    kv('Status', TextCellValue(employee.status.name));
    if (includeSalary) {
      kv('Current salary',
          TextCellValue(employee.salary?.toStringAsFixed(0) ?? '-'));
    }
    kv('Present (days)', IntCellValue(presentDays));
    kv('Late', IntCellValue(lateDays));
    kv('Leave (days)', IntCellValue(leaveDays));
    kv('Absent (days)', IntCellValue(absentDays));

    final att = excel['Attendance'];
    att.appendRow([
      TextCellValue('Date'),
      TextCellValue('Status'),
      TextCellValue('Source'),
    ]);
    for (final a in attendance) {
      att.appendRow([
        TextCellValue(a.date),
        TextCellValue(a.status),
        TextCellValue(a.source),
      ]);
    }

    if (includeSalary) {
      final sal = excel['Salary'];
      sal.appendRow([
        TextCellValue('Month'),
        TextCellValue('Year'),
        TextCellValue('Base'),
        TextCellValue('Bonus'),
        TextCellValue('Deductions'),
        TextCellValue('Net'),
        TextCellValue('Status'),
      ]);
      for (final p in payroll) {
        sal.appendRow([
          IntCellValue(p.month),
          IntCellValue(p.year),
          DoubleCellValue(p.baseSalary),
          DoubleCellValue(p.bonuses),
          DoubleCellValue(p.deductions),
          DoubleCellValue(p.calculatedNet),
          TextCellValue(p.status.name),
        ]);
      }
    }

    final lv = excel['Leave'];
    lv.appendRow([
      TextCellValue('Type'),
      TextCellValue('From'),
      TextCellValue('To'),
      TextCellValue('Days'),
      TextCellValue('Status'),
      TextCellValue('Reason'),
    ]);
    for (final l in leaves) {
      lv.appendRow([
        TextCellValue(l.leaveType.name),
        TextCellValue(_dayFormat.format(l.startDate)),
        TextCellValue(_dayFormat.format(l.endDate)),
        IntCellValue(l.days),
        TextCellValue(l.status.name),
        TextCellValue(l.reason ?? ''),
      ]);
    }

    final def = excel.getDefaultSheet();
    const kept = {'summary', 'attendance', 'salary', 'leave'};
    if (def != null && !kept.contains(def.toLowerCase())) {
      excel.delete(def);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List> buildPayrollExcel(List<PayrollModel> records) async {
    final excel = Excel.createExcel();
    final sheet = excel['Payroll'];
    sheet.appendRow([
      TextCellValue('Employee'),
      TextCellValue('Month'),
      TextCellValue('Year'),
      TextCellValue('Base'),
      TextCellValue('Overtime'),
      TextCellValue('Deductions'),
      TextCellValue('Bonuses'),
      TextCellValue('Net'),
      TextCellValue('Status'),
    ]);
    for (final p in records) {
      sheet.appendRow([
        TextCellValue(p.employeeName),
        IntCellValue(p.month),
        IntCellValue(p.year),
        DoubleCellValue(p.baseSalary),
        DoubleCellValue(p.overtime),
        DoubleCellValue(p.deductions),
        DoubleCellValue(p.bonuses),
        DoubleCellValue(p.calculatedNet),
        TextCellValue(p.status.name),
      ]);
    }
    return Uint8List.fromList(excel.encode()!);
  }
}
