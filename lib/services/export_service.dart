import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/attendance_model.dart';
import '../models/employee_model.dart';
import '../models/leave_model.dart';
import '../models/payroll_model.dart';

class ExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  Future<void> shareAttendancePdf(List<AttendanceModel> records) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Attendance Report')),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
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
          pw.Table.fromTextArray(
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
          pw.Table.fromTextArray(
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
