import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/leave_model.dart';
import 'data_providers.dart';

/// One leave type's entitlement vs. usage for an employee, this leave year.
class LeaveBalance {
  const LeaveBalance({
    required this.type,
    required this.allowance,
    required this.used,
  });

  final LeaveType type;
  final int allowance; // entitled days this year
  final int used; // approved days taken this year

  int get remaining => allowance - used;
  bool get overLimit => used > allowance;
}

/// Per-employee leave balances for the current calendar year, computed from
/// their approved leave history and the company's configured allowances. Only
/// tracked types (allowance > 0) are returned. Recomputes live as leaves or
/// settings change. Empty while either source is still loading.
final employeeLeaveBalancesProvider =
    Provider.family<List<LeaveBalance>, String>((ref, employeeId) {
  final leaves =
      ref.watch(employeeLeaveHistoryProvider(employeeId)).valueOrNull;
  final settings = ref.watch(companySettingsProvider).valueOrNull;
  if (leaves == null || settings == null) return const [];

  final year = DateTime.now().year;
  final result = <LeaveBalance>[];
  for (final type in LeaveType.values) {
    final allowance = settings.allowanceForName(type.name);
    if (allowance <= 0) continue; // untracked (e.g. unpaid / other)
    final used = leaves
        .where((l) =>
            l.leaveType == type &&
            l.status == LeaveStatus.approved &&
            l.startDate.year == year)
        .fold<int>(0, (sum, l) => sum + l.days);
    result.add(LeaveBalance(type: type, allowance: allowance, used: used));
  }
  return result;
});
