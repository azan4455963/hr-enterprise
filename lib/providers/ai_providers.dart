import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../models/ai_assistant_model.dart';
import '../services/ai_assistant_service.dart';
import 'data_providers.dart';
import 'data_table_providers.dart';

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

  // Custom tables
  buf.writeln('=== CUSTOM TABLES (${tables.length}) ===');
  var tableBudget = 600; // total row cap across all tables
  for (final t in tables) {
    buf.writeln('Table "${t.name}" [${t.columns.join(", ")}]:');
    final rowCap = t.rows.length.clamp(0, 60);
    for (final row in t.rows.take(rowCap)) {
      if (tableBudget <= 0) break;
      buf.writeln('  ${row.join(" | ")}');
      tableBudget--;
    }
    if (t.rows.length > rowCap) {
      buf.writeln('  ...(${t.rows.length - rowCap} more rows omitted)');
    }
    if (tableBudget <= 0) {
      buf.writeln('...(remaining tables omitted to stay within size limits)');
      break;
    }
  }

  return buf.toString();
});
