import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/data_table_model.dart';
import 'data_table_providers.dart';

/// How a single status cell is bucketed.
enum AttBucket { present, late, leave, absent, terminated, off, blank }

AttBucket classifyStatus(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return AttBucket.blank;
  if (v == '-' || v == '–' || v == '—') return AttBucket.off;
  if (v.contains('terminate')) return AttBucket.terminated;
  if (v.contains('leave') || v.contains('vacation')) return AttBucket.leave;
  if (v.contains('absent')) return AttBucket.absent;
  if (v.contains('late')) return AttBucket.late;
  if (v.contains('present') || v.contains('hour') || v.contains('half')) {
    return AttBucket.present;
  }
  return AttBucket.blank;
}

/// One department's attendance for the target day.
class DeptDayAttendance {
  const DeptDayAttendance({
    required this.department,
    required this.present,
    required this.late,
    required this.leave,
    required this.absent,
    required this.terminated,
    required this.totalPeople,
    required this.isOff,
  });

  final String department;
  final int present; // includes late (late are present-at-work)
  final int late;
  final int leave;
  final int absent;
  final int terminated;
  final int totalPeople; // employee columns counted (excl. terminated)
  final bool isOff; // whole day marked off ("-")
}

/// All departments + grand totals for a given day.
class TodayAttendance {
  const TodayAttendance({required this.date, required this.departments});
  final DateTime date;
  final List<DeptDayAttendance> departments;

  bool get hasData => departments.isNotEmpty;
  int get present => departments.fold(0, (s, d) => s + d.present);
  int get late => departments.fold(0, (s, d) => s + d.late);
  int get leave => departments.fold(0, (s, d) => s + d.leave);
  int get absent => departments.fold(0, (s, d) => s + d.absent);
  int get totalPeople => departments.fold(0, (s, d) => s + d.totalPeople);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Flexibly parse a date cell ("01-Jun-2026", "06/01/2026", ISO, …).
DateTime? _parseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  for (final f in const [
    'dd-MMM-yyyy',
    'd-MMM-yyyy',
    'dd-MM-yyyy',
    'MM/dd/yyyy',
    'dd/MM/yyyy',
    'yyyy-MM-dd',
  ]) {
    try {
      return DateFormat(f).parseStrict(s);
    } catch (_) {/* try next */}
  }
  return DateTime.tryParse(s);
}

/// Find a sheet's column index by exact (case-insensitive) header name.
int _col(List<String> cols, String name) =>
    cols.indexWhere((c) => c.trim().toLowerCase() == name.toLowerCase());

/// Compute today's attendance for one department table, or null if the table
/// has no sheet with a Date column containing the target day.
DeptDayAttendance? _deptForDay(DataTableModel table, DateTime day) {
  for (final sheet in table.sheets) {
    final dateIdx = _col(sheet.columns, 'date');
    if (dateIdx < 0) continue;
    final dayIdx = _col(sheet.columns, 'working days');
    final altDayIdx = dayIdx >= 0 ? dayIdx : _col(sheet.columns, 'day');

    // Employee columns = everything except date + day columns.
    final empCols = <int>[
      for (var i = 0; i < sheet.columns.length; i++)
        if (i != dateIdx && i != altDayIdx && sheet.columns[i].trim().isNotEmpty)
          i,
    ];
    if (empCols.isEmpty) continue;

    for (final row in sheet.rows) {
      if (dateIdx >= row.length) continue;
      final d = _parseDate(row[dateIdx]);
      if (d == null || !_sameDay(d, day)) continue;

      var present = 0, late = 0, leave = 0, absent = 0, terminated = 0;
      var offCells = 0, counted = 0;
      for (final c in empCols) {
        final cell = c < row.length ? row[c] : '';
        switch (classifyStatus(cell)) {
          case AttBucket.present:
            present++;
            counted++;
            break;
          case AttBucket.late:
            late++;
            present++; // late still counts as present-at-work
            counted++;
            break;
          case AttBucket.leave:
            leave++;
            counted++;
            break;
          case AttBucket.absent:
            absent++;
            counted++;
            break;
          case AttBucket.terminated:
            terminated++;
            break;
          case AttBucket.off:
            offCells++;
            break;
          case AttBucket.blank:
            break;
        }
      }
      final isOff = counted == 0 && offCells > 0;
      return DeptDayAttendance(
        department: table.name,
        present: present,
        late: late,
        leave: leave,
        absent: absent,
        terminated: terminated,
        totalPeople: counted,
        isOff: isOff,
      );
    }
  }
  return null;
}

/// Aggregate today's attendance across all department tables.
TodayAttendance computeTodayAttendance(
    List<DataTableModel> tables, DateTime day) {
  final depts = <DeptDayAttendance>[];
  for (final t in tables) {
    final d = _deptForDay(t, day);
    if (d != null && !d.isOff) depts.add(d);
  }
  depts.sort((a, b) => a.department.compareTo(b.department));
  return TodayAttendance(date: day, departments: depts);
}

/// Live: recomputes whenever any table changes. Uses the current date, so it
/// rolls over to the new day automatically.
final tableAttendanceTodayProvider = Provider<TodayAttendance>((ref) {
  final tables = ref.watch(dataTablesProvider).valueOrNull ?? const [];
  return computeTodayAttendance(tables, DateTime.now());
});

/// One per-employee attendance entry for a day (for the log view).
class AttendanceLogEntry {
  const AttendanceLogEntry({
    required this.department,
    required this.employee,
    required this.status,
    required this.bucket,
  });
  final String department;
  final String employee;
  final String status;
  final AttBucket bucket;
}

/// Flatten the day's attendance across all department tables into per-employee
/// log entries (skips empty/off cells).
List<AttendanceLogEntry> computeTodayLog(
    List<DataTableModel> tables, DateTime day) {
  final out = <AttendanceLogEntry>[];
  for (final t in tables) {
    for (final sheet in t.sheets) {
      final dateIdx = _col(sheet.columns, 'date');
      if (dateIdx < 0) continue;
      final dayIdx = _col(sheet.columns, 'working days');
      final altDayIdx = dayIdx >= 0 ? dayIdx : _col(sheet.columns, 'day');
      final empCols = <int>[
        for (var i = 0; i < sheet.columns.length; i++)
          if (i != dateIdx &&
              i != altDayIdx &&
              sheet.columns[i].trim().isNotEmpty)
            i,
      ];
      if (empCols.isEmpty) continue;
      for (final row in sheet.rows) {
        if (dateIdx >= row.length) continue;
        final d = _parseDate(row[dateIdx]);
        if (d == null || !_sameDay(d, day)) continue;
        for (final c in empCols) {
          final cell = (c < row.length ? row[c] : '').trim();
          final bucket = classifyStatus(cell);
          if (bucket == AttBucket.blank || bucket == AttBucket.off) continue;
          out.add(AttendanceLogEntry(
            department: t.name,
            employee: sheet.columns[c],
            status: cell,
            bucket: bucket,
          ));
        }
        break; // only the matching date row per sheet
      }
    }
  }
  out.sort((a, b) => a.employee.compareTo(b.employee));
  return out;
}

/// Today's per-employee attendance log from in-app tables (live).
final tableAttendanceLogProvider = Provider<List<AttendanceLogEntry>>((ref) {
  final tables = ref.watch(dataTablesProvider).valueOrNull ?? const [];
  return computeTodayLog(tables, DateTime.now());
});
