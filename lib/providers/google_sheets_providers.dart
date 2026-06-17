import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/google_sheet_model.dart';
import '../services/google_sheets_service.dart';
import 'auth_provider.dart';
import 'service_providers.dart';

final googleSheetsServiceProvider = Provider<GoogleSheetsService>((ref) {
  return GoogleSheetsService();
});

/// Stream of all attached Google Sheets, ordered
final googleSheetsListProvider = StreamProvider<List<GoogleSheetModel>>((ref) {
  return ref.watch(googleSheetsServiceProvider).watchSheets();
});

/// Provider for fetching sheet data (CSV) on demand for a specific tab (gid).
final googleSheetDataProvider = FutureProvider.family<List<List<String>>,
    ({String sheetId, int gid})>((ref, key) async {
  return ref
      .watch(googleSheetsServiceProvider)
      .fetchSheetData(key.sheetId, sheetIndex: key.gid);
});

/// Ticks every 2 minutes so dependent providers auto-refresh.
/// Google "publish to web" has no push channel, so we poll.
final sheetsAutoRefreshProvider = StreamProvider<int>((ref) async* {
  var tick = 0;
  yield tick;
  while (true) {
    await Future.delayed(const Duration(seconds: 90));
    yield ++tick;
  }
});

/// Auto-computed summaries for every attached sheet, refreshed on each tick.
/// Detects status columns and counts their values for the dashboard.
final sheetSummariesProvider = FutureProvider<List<SheetSummary>>((ref) async {
  // Re-run whenever the poll timer ticks.
  ref.watch(sheetsAutoRefreshProvider);

  final sheets = await ref.watch(googleSheetsListProvider.future);
  final service = ref.watch(googleSheetsServiceProvider);

  final summaries = <SheetSummary>[];
  for (final sheet in sheets) {
    try {
      final rows =
          await service.fetchSheetData(sheet.sheetId, sheetIndex: sheet.gid);
      summaries.add(service.buildSummary(sheet: sheet, rows: rows));
    } catch (e) {
      summaries.add(SheetSummary.error(sheet, e.toString()));
    }
  }
  return summaries;
});

/// Every attendance-style sheet, each summarised on its own (per department,
/// per month). Used by the attendance screen's department filter.
final allAttendanceSheetSummariesProvider =
    FutureProvider<List<AttendanceSheetSummary>>((ref) async {
  ref.watch(sheetsAutoRefreshProvider);

  final sheets = await ref.watch(googleSheetsListProvider.future);
  final service = ref.watch(googleSheetsServiceProvider);

  final result = <AttendanceSheetSummary>[];
  for (final sheet in sheets) {
    try {
      final rows =
          await service.fetchSheetData(sheet.sheetId, sheetIndex: sheet.gid);
      final summary = service.buildAttendanceSummary(sheet: sheet, rows: rows);
      if (summary != null) result.add(summary);
    } catch (_) {
      // Skip sheets that fail to load.
    }
  }
  return result;
});

/// Combined attendance across ALL departments (sum of every attendance sheet).
/// Powers the dashboard. Null when no sheet looks like attendance.
final attendanceSheetSummaryProvider =
    FutureProvider<AttendanceSheetSummary?>((ref) async {
  final all = await ref.watch(allAttendanceSheetSummariesProvider.future);
  if (all.isEmpty) return null;
  return combineAttendanceSummaries(all, department: 'All Departments');
});

/// Sum a list of attendance summaries into one. Period label is kept only when
/// every summary shares the same month.
AttendanceSheetSummary combineAttendanceSummaries(
  List<AttendanceSheetSummary> list, {
  required String department,
}) {
  var present = 0, absent = 0, leave = 0, other = 0, headcount = 0;
  final periods = <String>{};
  for (final s in list) {
    present += s.present;
    absent += s.absent;
    leave += s.leave;
    other += s.other;
    headcount += s.headcount;
    if (s.periodLabel != null) periods.add(s.periodLabel!);
  }
  return AttendanceSheetSummary(
    sheetTitle: department,
    present: present,
    absent: absent,
    leave: leave,
    other: other,
    headcount: headcount,
    periodLabel: periods.length == 1 ? periods.first : null,
    department: department,
  );
}

/// All sheet rows belonging to one person, gathered across every attached
/// sheet and matched by name OR email. Powers the "Sheet Data" profile tab.
final employeeSheetRecordsProvider = FutureProvider.family<List<SheetMatch>,
    ({String name, String email})>((ref, key) async {
  ref.watch(sheetsAutoRefreshProvider);

  final sheets = await ref.watch(googleSheetsListProvider.future);
  final service = ref.watch(googleSheetsServiceProvider);

  final matches = <SheetMatch>[];
  for (final sheet in sheets) {
    try {
      final rows =
          await service.fetchSheetData(sheet.sheetId, sheetIndex: sheet.gid);
      final found =
          service.findRowsFor(rows: rows, name: key.name, email: key.email);
      if (found.isNotEmpty) {
        matches.add(SheetMatch(sheetTitle: sheet.title, records: found));
      }
    } catch (_) {
      // Skip sheets that fail to load.
    }
  }
  return matches;
});

/// Background worker: when a sheet has [GoogleSheetModel.syncEmployees] on, it
/// upserts that sheet's rows into the employees collection on every poll tick.
///
/// Keep this alive by watching [employeeSheetSyncProvider] from a long-lived
/// widget (the app shell). Only runs for users allowed to create employees.
class EmployeeSheetSyncer {
  EmployeeSheetSyncer(this._ref) {
    _ref.listen(
      sheetsAutoRefreshProvider,
      (_, _) => _run(),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;

    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.hasPermission('employees_create')) return;

    final sheets = _ref.read(googleSheetsListProvider).valueOrNull;
    if (sheets == null) return;
    final syncSheets = sheets.where((s) => s.syncEmployees).toList();
    if (syncSheets.isEmpty) return;

    _busy = true;
    try {
      final sheetsService = _ref.read(googleSheetsServiceProvider);
      final employeeService = _ref.read(employeeServiceProvider);
      for (final sheet in syncSheets) {
        try {
          final rows = await sheetsService.fetchSheetData(sheet.sheetId);
          final parsed = sheetsService.parseEmployees(rows);
          if (parsed.isEmpty) continue;
          await employeeService.upsertEmployees(
            parsed.employees,
            userId: user.id,
          );
        } catch (_) {
          // Skip sheets that fail to load/parse this round.
        }
      }
    } finally {
      _busy = false;
    }
  }
}

final employeeSheetSyncProvider = Provider<EmployeeSheetSyncer>((ref) {
  return EmployeeSheetSyncer(ref);
});
