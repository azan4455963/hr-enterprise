import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../models/ai_assistant_model.dart';
import '../models/data_table_model.dart';
import '../models/employee_model.dart';
import '../services/ai_assistant_service.dart';
import 'data_providers.dart';
import 'data_table_providers.dart';
import 'table_attendance_providers.dart';

final aiAssistantServiceProvider =
    Provider<AiAssistantService>((ref) => AiAssistantService());

/// Whether the slide-in AI chat panel is open.
final aiPanelOpenProvider = StateProvider<bool>((ref) => false);

/// Persisted AI config (provider + key + model), stored securely on-device.
final aiConfigProvider =
    StateNotifierProvider<AiConfigNotifier, AsyncValue<AiConfig?>>(
        (ref) => AiConfigNotifier());

class AiConfigNotifier extends StateNotifier<AsyncValue<AiConfig?>> {
  AiConfigNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _key = 'ai_assistant_config_v1';

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      state = AsyncValue.data(
          raw == null ? null : AiConfig.fromMap(jsonDecode(raw)));
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> save(AiConfig config) async {
    await _storage.write(key: _key, value: jsonEncode(config.toMap()));
    state = AsyncValue.data(config);
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    state = const AsyncValue.data(null);
  }
}

/// Builds a compact, bounded snapshot of all HR data for the AI to reason over.
/// Admin-only feature, so salary and full details are included.
final aiDataContextProvider = FutureProvider<String>((ref) async {
  final employees = await ref.watch(employeesProvider.future);
  final leaves = await ref.watch(leaveRequestsProvider.future);
  final attendance = await ref.watch(recentAttendanceProvider.future);
  final payroll = await ref.watch(payrollProvider.future);
  final tables = await ref.watch(dataTablesProvider.future);
  final departments = await ref.watch(departmentsProvider.future);

  final dayFmt = DateFormat('dd-MMM-yyyy');
  final timeFmt = DateFormat('hh:mm a');
  final buf = StringBuffer();

  buf.writeln('Today: ${dayFmt.format(DateTime.now())}');
  buf.writeln();

  // Employees
  buf.writeln('=== EMPLOYEES (${employees.length}) ===');
  for (final e in employees.take(250)) {
    final shortId = e.id.length >= 6 ? e.id.substring(0, 6) : e.id;
    buf.writeln('- ${e.fullName} | dept: ${e.departmentName ?? "-"} '
        '| role: ${e.position ?? "-"} | status: ${e.status.name} '
        '| email: ${e.email} | phone: ${e.phone ?? "-"} '
        '| cnic: ${e.cnic ?? "-"} '
        '| joined: ${e.joiningDate != null ? dayFmt.format(e.joiningDate!) : "-"} '
        '| salary: ${e.salary?.toStringAsFixed(0) ?? "-"} | id: $shortId');
  }
  if (employees.length > 250) {
    buf.writeln('...(${employees.length - 250} more employees omitted)');
  }
  buf.writeln();

  // Departments
  buf.writeln('=== DEPARTMENTS (${departments.length}) ===');
  for (final d in departments) {
    final count = employees
        .where((e) =>
            (e.departmentName ?? '').toLowerCase() == d.name.toLowerCase())
        .length;
    buf.writeln('- ${d.name}: $count employees'
        '${(d.description?.isNotEmpty ?? false) ? " — ${d.description}" : ""}');
  }
  buf.writeln();

  // Leave
  buf.writeln('=== LEAVE REQUESTS (${leaves.length}) ===');
  for (final l in leaves.take(200)) {
    buf.writeln('- ${l.employeeName}: ${l.leaveType.name} ${l.days}d '
        '${dayFmt.format(l.startDate)}→${dayFmt.format(l.endDate)} '
        '[${l.status.name}]${(l.reason?.isNotEmpty ?? false) ? " — ${l.reason}" : ""}');
  }
  buf.writeln();

  // Attendance (recent)
  final sortedAtt = [...attendance]..sort((a, b) => b.date.compareTo(a.date));
  buf.writeln('=== ATTENDANCE — last 30 days (${sortedAtt.length} records) ===');
  for (final a in sortedAtt.take(300)) {
    final inT = a.checkIn != null ? timeFmt.format(a.checkIn!) : '-';
    final outT = a.checkOut != null ? timeFmt.format(a.checkOut!) : '-';
    buf.writeln('- ${a.employeeName ?? a.employeeId} ${dayFmt.format(a.date)}: '
        '${a.status.name} (in $inT, out $outT)');
  }
  if (sortedAtt.length > 300) {
    buf.writeln('...(${sortedAtt.length - 300} more records omitted)');
  }
  buf.writeln();

  // Payroll (current month)
  buf.writeln('=== PAYROLL — current month (${payroll.length}) ===');
  for (final p in payroll.take(200)) {
    buf.writeln('- ${p.employeeName} ${p.month}/${p.year}: '
        'net ${p.calculatedNet.toStringAsFixed(0)} '
        '(base ${p.baseSalary.toStringAsFixed(0)}, '
        'bonus ${p.bonuses.toStringAsFixed(0)}, '
        'deduct ${p.deductions.toStringAsFixed(0)}) [${p.status.name}]');
  }
  buf.writeln();

  // Custom tables — directory only (names, tabs, columns, row counts). The
  // actual rows/cells are surfaced on demand via SEARCH MATCHES (any word) or
  // the focused dossier (a named person), which keeps this snapshot small.
  buf.writeln('=== CUSTOM TABLES (${tables.length}) ===');
  for (final t in tables) {
    buf.writeln('Table "${t.name}":');
    for (final sheet in t.sheets) {
      buf.writeln('  Tab "${sheet.name}" — ${sheet.rows.length} rows, '
          'columns: [${sheet.columns.join(", ")}]');
    }
  }
  buf.writeln('(Row-level table data is provided in the SEARCH MATCHES section '
      'when you ask about a specific name, date or word.)');

  return buf.toString();
});

/// If the question names a known employee, return a focused dossier (all of
/// that person's data) so the AI answers precisely; else null.
Future<({String name, String dossier})?> employeeFocusedDossier(
    WidgetRef ref, String question) async {
  final q = question.toLowerCase();
  final employees = await ref.read(employeesProvider.future);
  EmployeeModel? match;
  for (final e in employees) {
    final full = e.fullName.toLowerCase();
    final first = e.firstName.toLowerCase();
    if (full.isNotEmpty && q.contains(full)) {
      match = e;
      break;
    }
    if (first.length > 2 && q.contains(first)) match ??= e;
  }
  if (match == null) return null;

  final id = match.id;
  final dayFmt = DateFormat('dd-MMM-yyyy');
  final att = await ref.read(employeeAttendanceHistoryProvider(id).future);
  final leaves = await ref.read(employeeLeaveHistoryProvider(id).future);
  final pay = await ref.read(employeePayrollHistoryProvider(id).future);
  final records = await ref.read(employeeRecordsProvider(id).future);
  final docs = await ref.read(employeeDocumentsProvider(id).future);

  final b = StringBuffer();
  b.writeln('=== EMPLOYEE DOSSIER: ${match.fullName} ===');
  b.writeln('Department: ${match.departmentName ?? "-"} | Role: '
      '${match.position ?? "-"} | Status: ${match.status.name} '
      '| Email: ${match.email} | Phone: ${match.phone ?? "-"} '
      '| CNIC: ${match.cnic ?? "-"} '
      '| Joined: ${match.joiningDate != null ? dayFmt.format(match.joiningDate!) : "-"} '
      '| Salary: ${match.salary?.toStringAsFixed(0) ?? "-"}');

  b.writeln('\n--- Attendance (recent) ---');
  for (final a in att.take(30)) {
    b.writeln('${dayFmt.format(a.date)}: ${a.status.name}');
  }

  b.writeln('\n--- Leave (${leaves.length}) ---');
  for (final l in leaves.take(30)) {
    b.writeln('${l.leaveType.name} ${l.days}d '
        '${dayFmt.format(l.startDate)}->${dayFmt.format(l.endDate)} '
        '[${l.status.name}]');
  }

  b.writeln('\n--- Payroll (${pay.length}) ---');
  for (final p in pay.take(24)) {
    b.writeln('${p.month}/${p.year}: net ${p.calculatedNet.toStringAsFixed(0)} '
        '(base ${p.baseSalary.toStringAsFixed(0)}, bonus ${p.bonuses.toStringAsFixed(0)}) '
        '[${p.status.name}]');
  }

  if (records.isNotEmpty) {
    b.writeln('\n--- Records (${records.length}) ---');
    for (final r in records.take(40)) {
      final fields = r.fields.map((f) => '${f.label}: ${f.value}').join('; ');
      b.writeln('[${r.category}] ${r.title}'
          '${fields.isNotEmpty ? " - $fields" : ""}'
          '${(r.note?.isNotEmpty ?? false) ? " (${r.note})" : ""}');
    }
  }

  if (docs.isNotEmpty) {
    b.writeln('\n--- Documents (${docs.length}) ---');
    for (final d in docs.take(40)) {
      b.writeln('${d.name} [${d.category}]');
    }
  }

  // Most attendance is kept in the custom Tables (one column per person), not
  // in Firestore — so pull this person's column(s) across every table/tab.
  final tables = await ref.read(dataTablesProvider.future);
  final tableAtt = personTableAttendance(tables, match);
  if (tableAtt.isNotEmpty) b.write(tableAtt);

  return (name: match.fullName, dossier: b.toString());
}

/// Pull one person's attendance out of the custom Tables. Attendance tables use
/// a matrix layout (a Date column + one column per employee), so we locate the
/// person's column and read down it. For non-matrix tables we fall back to any
/// row that mentions the person. Returns '' if nothing is found.
String personTableAttendance(List<DataTableModel> tables, EmployeeModel emp) {
  final fullL = emp.fullName.toLowerCase().trim();
  final firstL = emp.firstName.toLowerCase().trim();
  bool isMeta(String h) {
    final v = h.trim().toLowerCase();
    return v.isEmpty || v == 'date' || v == 'day' || v == 'working days';
  }

  bool headerMatches(String header) {
    final h = header.trim().toLowerCase();
    if (h == fullL) return true;
    if (firstL.length > 2 && h.contains(firstL)) return true;
    if (h.length > 2 && fullL.contains(h)) return true;
    return false;
  }

  // Collect per-tab summary counts (always) + every dated day entry (so we can
  // keep only the most-recent N and stay small for low-token providers).
  final summaries = <String>[];
  final dayEntries =
      <({DateTime? date, String label})>[]; // label = "dd-MMM: status [tab]"
  final mentions = <String>[];

  for (final t in tables) {
    for (final sheet in t.sheets) {
      final cols = sheet.columns;
      final dateIdx =
          cols.indexWhere((c) => c.trim().toLowerCase() == 'date');
      final personCols = <int>[
        for (var i = 0; i < cols.length; i++)
          if (!isMeta(cols[i]) && headerMatches(cols[i])) i,
      ];

      if (personCols.isNotEmpty) {
        for (final ci in personCols) {
          var present = 0, late = 0, leave = 0, absent = 0, count = 0;
          for (final row in sheet.rows) {
            final cell = ci < row.length ? row[ci].trim() : '';
            if (cell.isEmpty) continue;
            final bucket = classifyStatus(cell);
            if (bucket == AttBucket.blank || bucket == AttBucket.off) continue;
            final dateStr =
                (dateIdx >= 0 && dateIdx < row.length) ? row[dateIdx].trim() : '';
            dayEntries.add((
              date: _tryParseTableDate(dateStr),
              label: '${dateStr.isEmpty ? "?" : dateStr}: $cell [${sheet.name}]',
            ));
            count++;
            switch (bucket) {
              case AttBucket.present:
                present++;
                break;
              case AttBucket.late:
                late++;
                present++;
                break;
              case AttBucket.leave:
                leave++;
                break;
              case AttBucket.absent:
                absent++;
                break;
              default:
                break;
            }
          }
          if (count == 0) continue;
          summaries.add('${t.name} › ${sheet.name}: present $present, '
              'late $late, leave $leave, absent $absent ($count days marked)');
        }
      } else {
        // Non-matrix table: note rows that mention the person.
        for (final row in sheet.rows) {
          final hay = row.join(' ').toLowerCase();
          if (hay.contains(fullL) ||
              (firstL.length > 2 && hay.contains(firstL))) {
            mentions.add('${t.name}›${sheet.name}: '
                '${row.where((c) => c.trim().isNotEmpty).join(" | ")}');
          }
        }
      }
    }
  }

  if (summaries.isEmpty && mentions.isEmpty) return '';

  // Most-recent first; undated rows sink to the bottom.
  dayEntries.sort((a, b) {
    if (a.date == null && b.date == null) return 0;
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    return b.date!.compareTo(a.date!);
  });

  final buf = StringBuffer('\n--- Attendance from custom Tables ---\n');
  for (final s in summaries) {
    buf.writeln('• $s');
  }
  if (dayEntries.isNotEmpty) {
    buf.writeln('Recent marked days (newest first):');
    for (final e in dayEntries.take(50)) {
      buf.writeln('  ${e.label}');
    }
    if (dayEntries.length > 50) {
      buf.writeln('  ...(${dayEntries.length - 50} older days — see totals above)');
    }
  }
  if (mentions.isNotEmpty) {
    buf.writeln('Other table mentions:');
    for (final m in mentions.take(12)) {
      buf.writeln('  $m');
    }
  }
  return buf.toString();
}

/// Loose date parse for table cells ("01-Jun-2026", "06/01/2026", ISO, …).
DateTime? _tryParseTableDate(String raw) {
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

/// Standing "how to use this app" guide so the AI can answer how-to questions
/// (create a table, add an employee, mark attendance, delete rows, …).
const String aiAppGuide = '''
=== APP GUIDE (how to do things in this app) ===
NAVIGATION: The left sidebar (desktop) or bottom bar (mobile) switches modules: Dashboard, Employees, Attendance, Leave, Payroll, Tables, Documents, Settings.

ADD AN EMPLOYEE: Employees module → "Add Employee" button (top-right) → fill name, department, role, salary, email, phone → Save. Click any employee row to view/edit their full profile, records and documents.

CREATE A TABLE: Tables module → "New Table". For attendance use "New Attendance Workbook" — it auto-creates 12 month tabs, each pre-filled with that month's dates and day names. A table can hold several tabs (sheets); the tabs appear along the bottom.

EDIT A TABLE: Open it and double-click a cell to type — it auto-saves every few seconds. Right-click a column header to rename it. "Fill Dates" auto-fills a month's date column; the totals toggle sums a numeric column.

MARK ATTENDANCE: Open the department's attendance table, find today's Date row, and type the status under the person's column — Present, Absent, Leave, Late, or "-" for an off/holiday cell. The Dashboard and Attendance screens then show today's totals automatically. You can also ask me "mark <name> present today" and confirm.

SELECT & DELETE ROWS: Click the checkbox in the "#" column to select a row. Ctrl-click (Cmd on Mac) adds scattered rows; Shift-click selects a range — exactly like Excel/Google Sheets. Then click "Delete N rows" or press the Delete key, and confirm.

CREATE LEAVE: Leave module → "New Request" → pick the employee, leave type, dates and reason → Save. Or ask me "create a sick leave for <name> from <date> to <date>" and confirm.

PAYROLL & PAYSLIP: Payroll module shows the current month's salaries (base, bonus, deductions, net). Open an employee to download their payslip as a PDF.

DOCUMENTS: Open an employee → Documents → upload files such as CNIC, contract or certificates.
=== END APP GUIDE ===''';

// Tokens too generic to be useful as search terms (English + common Urdu).
const Set<String> _searchStop = {
  'the', 'and', 'for', 'with', 'show', 'list', 'tell', 'give', 'what', 'whats',
  'who', 'whom', 'how', 'why', 'when', 'where', 'which', 'this', 'that', 'have',
  'has', 'had', 'are', 'was', 'were', 'will', 'would', 'should', 'about', 'from',
  'into', 'please', 'all', 'any', 'get', 'got', 'find', 'search', 'data',
  'record', 'records', 'info', 'detail', 'details', 'total', 'name',
  'kia', 'kya', 'kaun', 'kon', 'konsa', 'konsi', 'batao', 'bata', 'bataye',
  'mujhe', 'muje', 'mera', 'meri', 'mere', 'hai', 'han', 'hain', 'liya', 'leya',
  'wala', 'wali', 'karo', 'kary', 'kar', 'aur', 'our', 'phir', 'jo', 'tha',
};

bool _keepToken(String t) =>
    t.length >= 3 || (t.length >= 2 && RegExp(r'^\d+$').hasMatch(t));

List<String> _searchKeywords(String q) {
  final out = <String>{};
  for (final w in q.toLowerCase().split(RegExp(r'[^a-z0-9@._]+'))) {
    final t = w.trim();
    if (!_keepToken(t) || _searchStop.contains(t)) continue;
    out.add(t);
  }
  return out.toList();
}

/// Keyword search across ALL data (employees, leave, payroll, departments and
/// every cell of every custom table tab) so even a single stray word can be
/// found. Returns the best-matching lines, or '' if nothing matches.
Future<String> aiSearchMatches(WidgetRef ref, String question) async {
  final keys = _searchKeywords(question);
  if (keys.isEmpty) return '';

  final hits = <({int score, String text})>[];
  void consider(String text) {
    final low = text.toLowerCase();
    var score = 0;
    for (final k in keys) {
      if (low.contains(k)) score++;
    }
    if (score > 0) hits.add((score: score, text: text));
  }

  final dayFmt = DateFormat('dd-MMM-yyyy');

  final employees = await ref.read(employeesProvider.future);
  for (final e in employees) {
    consider('EMPLOYEE ${e.fullName} | dept ${e.departmentName ?? "-"} | '
        'role ${e.position ?? "-"} | ${e.email} | phone ${e.phone ?? "-"} | '
        'cnic ${e.cnic ?? "-"} | salary ${e.salary?.toStringAsFixed(0) ?? "-"} | '
        '${e.status.name}');
  }

  final leaves = await ref.read(leaveRequestsProvider.future);
  for (final l in leaves) {
    consider('LEAVE ${l.employeeName} | ${l.leaveType.name} ${l.days}d | '
        '${dayFmt.format(l.startDate)}→${dayFmt.format(l.endDate)} | '
        '${l.status.name}${(l.reason?.isNotEmpty ?? false) ? " | ${l.reason}" : ""}');
  }

  final payroll = await ref.read(payrollProvider.future);
  for (final p in payroll) {
    consider('PAYROLL ${p.employeeName} | ${p.month}/${p.year} | '
        'net ${p.calculatedNet.toStringAsFixed(0)} | '
        'base ${p.baseSalary.toStringAsFixed(0)} | '
        'bonus ${p.bonuses.toStringAsFixed(0)} | '
        'deduct ${p.deductions.toStringAsFixed(0)} | ${p.status.name}');
  }

  final departments = await ref.read(departmentsProvider.future);
  for (final d in departments) {
    consider('DEPARTMENT ${d.name}'
        '${(d.description?.isNotEmpty ?? false) ? " | ${d.description}" : ""}');
  }

  final tables = await ref.read(dataTablesProvider.future);
  for (final t in tables) {
    for (final sheet in t.sheets) {
      final cols = sheet.columns;
      for (final row in sheet.rows) {
        final parts = <String>[];
        for (var i = 0; i < row.length; i++) {
          final v = row[i].trim();
          if (v.isEmpty) continue;
          final col = i < cols.length ? cols[i] : 'col${i + 1}';
          parts.add('$col=$v');
        }
        if (parts.isEmpty) continue;
        consider('TABLE ${t.name}›${sheet.name}: ${parts.join(" | ")}');
      }
    }
  }

  if (hits.isEmpty) return '';
  hits.sort((a, b) => b.score.compareTo(a.score));
  final top = hits.take(55).map((e) => e.text).toList();
  return '=== SEARCH MATCHES for "${question.trim()}" ===\n${top.join("\n")}';
}
