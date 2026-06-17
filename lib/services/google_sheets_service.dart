import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/employee_model.dart';
import '../models/google_sheet_model.dart';

class GoogleSheetsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _sheetsRef => _firestore.collection('google_sheets');

  /// Watch all attached sheets (ordered)
  Stream<List<GoogleSheetModel>> watchSheets() {
    return _sheetsRef
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => GoogleSheetModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// Add a new Google Sheet
  Future<void> addSheet({
    required String title,
    required String url,
    required String addedBy,
  }) async {
    final sheetId = GoogleSheetModel.extractSheetId(url);
    if (sheetId.isEmpty) {
      throw Exception('Invalid Google Sheets URL. Could not extract Sheet ID.');
    }

    // Get count for ordering
    final count = await _sheetsRef.get().then((s) => s.docs.length);

    await _sheetsRef.add({
      'title': title,
      'url': url,
      'sheetId': sheetId,
      'addedBy': addedBy,
      'addedAt': Timestamp.now(),
      'order': count,
    });
  }

  /// Update sheet title and URL
  Future<void> updateSheet(String docId, {String? title, String? url}) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (url != null) {
      updates['url'] = url;
      updates['sheetId'] = GoogleSheetModel.extractSheetId(url);
    }
    await _sheetsRef.doc(docId).update(updates);
  }

  /// Toggle whether this sheet auto-syncs into the employees collection.
  Future<void> setSyncEmployees(String docId, bool enabled) async {
    await _sheetsRef.doc(docId).update({'syncEmployees': enabled});
  }

  /// Delete a sheet
  Future<void> deleteSheet(String docId) async {
    await _sheetsRef.doc(docId).delete();
  }

  /// Reorder sheets
  Future<void> reorderSheets(List<GoogleSheetModel> sheets) async {
    final batch = _firestore.batch();
    for (var i = 0; i < sheets.length; i++) {
      batch.update(_sheetsRef.doc(sheets[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// Fetch sheet data as CSV (published sheets only)
  /// Requires the sheet to be published to the web
  /// Format: https://docs.google.com/spreadsheets/d/{sheetId}/export?format=csv
  Future<List<List<String>>> fetchSheetData(
    String sheetId, {
    int? sheetIndex = 0,
  }) async {
    // Published-to-web ids (start with 2PACX-) use the /d/e/{id}/pub endpoint;
    // normal sheet ids use /d/{id}/export.
    final String url;
    if (sheetId.startsWith('2PACX')) {
      final gid = sheetIndex ?? 0;
      url =
          'https://docs.google.com/spreadsheets/d/e/$sheetId/pub?output=csv&single=true&gid=$gid';
    } else {
      url = sheetIndex != null
          ? 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$sheetIndex'
          : 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv';
    }

    // Cache-buster: a unique query param + no-cache headers force Google/CDN/
    // browser to return the latest sheet contents on every refresh.
    final bust = DateTime.now().millisecondsSinceEpoch;
    final fullUrl = '$url&_cb=$bust';

    try {
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: const {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch sheet (status ${response.statusCode}). '
          'Make sure the sheet is published to the web: '
          'File > Share > Publish to web',
        );
      }

      return parseCsv(response.body);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to fetch sheet data: $e');
    }
  }

  /// Parse a raw CSV string into rows of cells.
  List<List<String>> parseCsv(String csv) {
    final lines = const LineSplitter().convert(csv);
    return lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) => _parseCsvLine(line))
        .toList();
  }

  /// Fetch sheet data as HTML (for published sheets - renders in WebView)
  String getSheetHtmlUrl(String sheetId, {int? sheetIndex}) {
    final base = 'https://docs.google.com/spreadsheets/d/e/$sheetId/pubhtml';
    if (sheetIndex != null) {
      return '$base?gid=$sheetIndex';
    }
    return base;
  }

  /// Build a generic summary from raw sheet rows.
  ///
  /// Auto-detects "status-like" columns (any header containing "status") and
  /// counts how many rows fall into each distinct value. If no status column
  /// is found, the last text column is used as a fallback.
  SheetSummary buildSummary({
    required GoogleSheetModel sheet,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      return SheetSummary(
        sheetId: sheet.sheetId,
        title: sheet.title,
        totalRows: 0,
        breakdowns: const [],
      );
    }

    final header = rows.first;

    // Matrix attendance sheet → summarise the latest day's present/absent/leave
    // instead of treating a name column as a status column.
    if (header.isNotEmpty &&
        header.first.trim().toLowerCase().contains('date')) {
      final dataRows = rows
          .sublist(1)
          .where((r) => r.any((c) => c.trim().isNotEmpty))
          .toList();
      final att = _buildMatrixAttendance(sheet, header, dataRows);
      final empCols = header
          .where((h) =>
              h.trim().isNotEmpty &&
              !h.toLowerCase().contains('date') &&
              !h.toLowerCase().contains('day'))
          .length;
      if (att != null) {
        return SheetSummary(
          sheetId: sheet.sheetId,
          title: sheet.title,
          totalRows: empCols,
          breakdowns: [
            SheetStatusBreakdown(
              column: 'Attendance · ${att.periodLabel ?? "latest"}',
              counts: {
                'Present': att.present,
                'Absent': att.absent,
                'Leave': att.leave,
              },
              blank: att.other,
            ),
          ],
        );
      }
    }
    final dataRows = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

    // Count only rows that have at least one non-empty cell.
    final filledRows = dataRows
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList();

    // Find columns whose header contains "status" (case-insensitive).
    var statusCols = <int>[];
    for (var i = 0; i < header.length; i++) {
      if (header[i].toLowerCase().contains('status')) statusCols.add(i);
    }

    // Fallback: if no explicit status column, use the last column.
    if (statusCols.isEmpty && header.isNotEmpty) {
      statusCols = [header.length - 1];
    }

    final breakdowns = <SheetStatusBreakdown>[];
    for (final col in statusCols) {
      final counts = <String, int>{};
      var blank = 0;
      for (final row in filledRows) {
        final raw = col < row.length ? row[col].trim() : '';
        if (raw.isEmpty) {
          blank++;
          continue;
        }
        // Group case-insensitively but keep the first-seen label casing.
        final existingKey = counts.keys.firstWhere(
          (k) => k.toLowerCase() == raw.toLowerCase(),
          orElse: () => raw,
        );
        counts[existingKey] = (counts[existingKey] ?? 0) + 1;
      }
      breakdowns.add(
        SheetStatusBreakdown(
          column: col < header.length ? header[col] : 'Column ${col + 1}',
          counts: counts,
          blank: blank,
        ),
      );
    }

    return SheetSummary(
      sheetId: sheet.sheetId,
      title: sheet.title,
      totalRows: filledRows.length,
      breakdowns: breakdowns,
    );
  }

  /// Scan a sheet's rows for attendance-like data and return present / absent
  /// / leave counts. Auto-detects a status column and classifies each value by
  /// keyword (P/present, A/absent, L/leave). Returns null if nothing looks
  /// like attendance, so the caller can hide the widget.
  AttendanceSheetSummary? buildAttendanceSummary({
    required GoogleSheetModel sheet,
    required List<List<String>> rows,
  }) {
    if (rows.length < 2) return null;

    final header = rows.first;
    final dataRows = rows
        .sublist(1)
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList();
    if (dataRows.isEmpty) return null;

    // ── Matrix layout: row 1 = Date, Day, <employee names…> and each row is a
    // day with each person's status. Detected when the first header is "Date".
    if (header.isNotEmpty && header.first.trim().toLowerCase().contains('date')) {
      return _buildMatrixAttendance(sheet, header, dataRows);
    }

    // Prefer a column whose header hints at attendance, else any "status" col.
    int? col;
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase();
      if (h.contains('attendance') ||
          h.contains('present') ||
          h.contains('status')) {
        col = i;
        if (h.contains('attendance') || h.contains('present')) break;
      }
    }
    if (col == null) return null;

    var present = 0, absent = 0, leave = 0, other = 0;
    for (final row in dataRows) {
      final raw = col < row.length ? row[col].trim().toLowerCase() : '';
      if (raw.isEmpty) {
        other++;
        continue;
      }
      // Absent/leave are checked before present so that words like
      // "inactive" (which contains "active") are not mis-counted as present.
      if (_matchesAny(
        raw,
        exact: ['l'],
        contains: ['leave', 'vacation'],
      )) {
        leave++;
      } else if (_matchesAny(
        raw,
        exact: ['a', 'off'],
        contains: [
          'absent',
          'missing',
          'inactive',
          'blocked',
          'left',
          'offline',
          'terminated',
        ],
      )) {
        absent++;
      } else if (_matchesAny(
        raw,
        exact: ['p', 'in'],
        contains: [
          'present',
          'here',
          'attended',
          'active',
          'working',
          'online',
          'available',
        ],
      )) {
        present++;
      } else {
        other++;
      }
    }

    // If nothing classified as attendance, this isn't an attendance sheet.
    if (present == 0 && absent == 0 && leave == 0) return null;

    return AttendanceSheetSummary(
      sheetTitle: sheet.title,
      present: present,
      absent: absent,
      leave: leave,
      other: other,
      headcount: present + absent + leave + other,
      department: _departmentFromTitle(sheet.title),
    );
  }

  /// Derive a department name from a sheet title by stripping the words
  /// "attendance" and any month/year tokens. "Billing Attendance Jun" → "Billing".
  String _departmentFromTitle(String title) {
    const months = {
      'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct',
      'nov', 'dec', 'january', 'february', 'march', 'april', 'june', 'july',
      'august', 'september', 'october', 'november', 'december',
    };
    final tokens = title.split(RegExp(r'[\s_\-]+')).where((t) {
      final l = t.trim().toLowerCase();
      if (l.isEmpty) return false;
      if (l.contains('attendance')) return false;
      if (months.contains(l)) return false;
      if (RegExp(r'^\d{2,4}$').hasMatch(l)) return false;
      return true;
    }).toList();
    final dept = tokens.join(' ').trim();
    return dept.isEmpty ? title.trim() : dept;
  }

  /// Classify a single status cell into present / absent / leave / other.
  String _classifyStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty || v == '-' || v == '--') return 'other';
    // Leave first, then absent (so "inactive" isn't read as "active"), then present.
    if (_matchesAny(v, contains: ['leave', 'vacation'])) return 'leave';
    if (_matchesAny(
      v,
      exact: ['a', 'off'],
      contains: [
        'absent',
        'missing',
        'inactive',
        'blocked',
        'terminate',
        'resign',
        'offline',
      ],
    )) {
      return 'absent';
    }
    if (_matchesAny(
      v,
      exact: ['p', 'in'],
      contains: [
        'present',
        'here',
        'attended',
        'active',
        'working',
        'online',
        'available',
        'late',
        'hour', // "8 Hours" worked = present
      ],
    )) {
      return 'present';
    }
    return 'other';
  }

  /// Matrix attendance: employees are columns, days are rows. Totals up the
  /// most recent month present in the sheet (auto-detected), so the dashboard
  /// shows that month's present / absent / leave day-counts.
  AttendanceSheetSummary? _buildMatrixAttendance(
    GoogleSheetModel sheet,
    List<String> header,
    List<List<String>> dataRows,
  ) {
    // Employee columns = header cells that aren't Date/Day and aren't empty.
    final empCols = <int>[];
    for (var i = 0; i < header.length; i++) {
      final h = header[i].trim().toLowerCase();
      if (h.isEmpty || h.contains('date') || h.contains('day')) continue;
      empCols.add(i);
    }
    if (empCols.isEmpty) return null;

    // Parse each row's date (column 0).
    final dated = <(DateTime, List<String>)>[];
    for (final row in dataRows) {
      final d = _parseSheetDate(row.isNotEmpty ? row[0] : '');
      if (d != null) dated.add((d, row));
    }
    if (dated.isEmpty) return null;
    dated.sort((a, b) => a.$1.compareTo(b.$1));

    // Pick TODAY's row (so the dashboard updates day-by-day). If today's row
    // has no real data yet, fall back to the latest day that does.
    final now = DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    bool hasReal(List<String> row) => empCols.any((c) {
          final v = (c < row.length ? row[c] : '').trim();
          return v.isNotEmpty && v != '-';
        });

    (DateTime, List<String>)? chosen;
    for (final e in dated) {
      if (sameDay(e.$1) && hasReal(e.$2)) {
        chosen = e;
        break;
      }
    }
    // Fallback: most recent day with real data.
    if (chosen == null) {
      for (var i = dated.length - 1; i >= 0; i--) {
        if (hasReal(dated[i].$2)) {
          chosen = dated[i];
          break;
        }
      }
    }
    if (chosen == null) return null;

    final date = chosen.$1;
    final row = chosen.$2;
    var present = 0, absent = 0, leave = 0, other = 0;
    for (final c in empCols) {
      final cell = c < row.length ? row[c] : '';
      switch (_classifyStatus(cell)) {
        case 'present':
          present++;
        case 'absent':
          absent++;
        case 'leave':
          leave++;
        default:
          other++;
      }
    }

    if (present == 0 && absent == 0 && leave == 0) return null;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = sameDay(date)
        ? 'Today'
        : '${date.day} ${months[date.month - 1]}';
    return AttendanceSheetSummary(
      sheetTitle: sheet.title,
      present: present,
      absent: absent,
      leave: leave,
      other: other,
      headcount: empCols.length,
      periodLabel: label,
      department: _departmentFromTitle(sheet.title),
    );
  }

  /// Parse a sheet date cell. Handles M/D/YYYY and ISO formats.
  DateTime? _parseSheetDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final parts = s.split('/');
    if (parts.length == 3) {
      final m = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (m != null && d != null && y != null) {
        return DateTime(y < 100 ? 2000 + y : y, m, d);
      }
    }
    return DateTime.tryParse(s);
  }

  bool _matchesAny(
    String value, {
    List<String> exact = const [],
    List<String> contains = const [],
  }) {
    for (final k in exact) {
      if (value == k) return true;
    }
    for (final k in contains) {
      if (value.contains(k)) return true;
    }
    return false;
  }

  /// Parse a sheet's rows into employee records by auto-mapping columns from
  /// the header (name, email, department, position/post, salary, phone, cnic).
  ///
  /// Rows missing a usable name are skipped. The returned employees have no id
  /// and `createdAt` set to now — they are ready to be persisted.
  SheetEmployeeImport parseEmployees(List<List<String>> rows) {
    if (rows.length < 2) {
      return const SheetEmployeeImport(employees: [], skippedRows: 0);
    }

    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();

    int? find(List<String> keywords) {
      for (var i = 0; i < header.length; i++) {
        for (final k in keywords) {
          if (header[i] == k || header[i].contains(k)) return i;
        }
      }
      return null;
    }

    final firstNameCol = find(['first name', 'fname', 'first']);
    final lastNameCol = find(['last name', 'lname', 'surname']);
    final fullNameCol = find(['employee name', 'full name', 'name']);
    final emailCol = find(['email', 'e-mail']);
    final deptCol = find(['department', 'dept']);
    final positionCol =
        find(['position', 'post', 'designation', 'title', 'role']);
    final salaryCol = find(['salary', 'pay', 'wage', 'package']);
    final phoneCol = find(['phone', 'mobile', 'contact', 'cell']);
    final cnicCol = find(['cnic', 'id card', 'nic', 'national id']);

    String cell(List<String> row, int? col) =>
        (col != null && col < row.length) ? row[col].trim() : '';

    final employees = <EmployeeModel>[];
    var skipped = 0;
    final now = DateTime.now();

    for (final row in rows.sublist(1)) {
      if (row.every((c) => c.trim().isEmpty)) continue;

      var first = cell(row, firstNameCol);
      var last = cell(row, lastNameCol);

      // No split name columns? fall back to a single full-name column.
      if (first.isEmpty && last.isEmpty) {
        final full = cell(row, fullNameCol);
        if (full.isEmpty) {
          skipped++;
          continue;
        }
        final parts = full.split(RegExp(r'\s+'));
        first = parts.first;
        last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }

      if (first.isEmpty) {
        skipped++;
        continue;
      }

      final dept = cell(row, deptCol);

      employees.add(
        EmployeeModel(
          id: '',
          firstName: first,
          lastName: last,
          email: cell(row, emailCol),
          phone: cell(row, phoneCol).isEmpty ? null : cell(row, phoneCol),
          cnic: cell(row, cnicCol).isEmpty ? null : cell(row, cnicCol),
          departmentName: dept.isEmpty ? null : dept,
          position: cell(row, positionCol).isEmpty
              ? null
              : cell(row, positionCol),
          salary: _parseSalary(cell(row, salaryCol)),
          status: EmployeeStatus.active,
          createdAt: now,
        ),
      );
    }

    return SheetEmployeeImport(employees: employees, skippedRows: skipped);
  }

  /// Find rows in a sheet that belong to a given person, matched by name OR
  /// email (case-insensitive). Returns each matched row as an ordered
  /// header→value map so the UI can show every column.
  List<Map<String, String>> findRowsFor({
    required List<List<String>> rows,
    required String name,
    required String email,
  }) {
    if (rows.length < 2) return const [];

    final header = rows.first;
    final wantName = name.trim().toLowerCase();
    final wantEmail = email.trim().toLowerCase();

    final matches = <Map<String, String>>[];
    for (final row in rows.sublist(1)) {
      if (row.every((c) => c.trim().isEmpty)) continue;

      var hit = false;
      for (final cell in row) {
        final v = cell.trim().toLowerCase();
        if (v.isEmpty) continue;
        if (wantEmail.isNotEmpty && v == wantEmail) {
          hit = true;
          break;
        }
        if (wantName.isNotEmpty && (v == wantName || v.contains(wantName))) {
          hit = true;
          break;
        }
      }
      if (!hit) continue;

      final map = <String, String>{};
      for (var i = 0; i < header.length; i++) {
        final key =
            header[i].trim().isEmpty ? 'Column ${i + 1}' : header[i].trim();
        map[key] = i < row.length ? row[i].trim() : '';
      }
      matches.add(map);
    }
    return matches;
  }

  double? _parseSalary(String raw) {
    if (raw.isEmpty) return null;
    // Strip currency symbols, commas and spaces.
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Simple CSV line parser (handles quoted fields)
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }
}
