import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee_model.dart';
import 'data_providers.dart';

enum ReminderType { birthday, anniversary, cnicExpiry, contractEnd }

/// One upcoming (or recently-overdue) event for an employee.
class Reminder {
  const Reminder({
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.date,
    required this.daysUntil,
  });

  final String employeeId;
  final String employeeName;
  final ReminderType type;
  final DateTime date; // the occurrence being reminded about
  final int daysUntil; // 0 = today, negative = overdue
}

/// How far ahead reminders look (days). Expiries also show if recently overdue.
const int reminderWindowDays = 45;
const int _overdueGraceDays = 120;

DateTime _nextAnnual(DateTime today, DateTime d) {
  var next = DateTime(today.year, d.month, d.day);
  if (next.isBefore(today)) next = DateTime(today.year + 1, d.month, d.day);
  return next;
}

/// Compute the active employees' upcoming birthdays, work anniversaries, CNIC
/// expiries and contract endings, soonest first.
List<Reminder> computeReminders(List<EmployeeModel> employees, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <Reminder>[];

  void addAnnual(EmployeeModel e, DateTime? d, ReminderType type) {
    if (d == null) return;
    final next = _nextAnnual(today, d);
    final days = next.difference(today).inDays;
    if (days <= reminderWindowDays) {
      out.add(Reminder(
        employeeId: e.id,
        employeeName: e.fullName,
        type: type,
        date: next,
        daysUntil: days,
      ));
    }
  }

  void addExpiry(EmployeeModel e, DateTime? d, ReminderType type) {
    if (d == null) return;
    final day = DateTime(d.year, d.month, d.day);
    final days = day.difference(today).inDays;
    if (days <= reminderWindowDays && days >= -_overdueGraceDays) {
      out.add(Reminder(
        employeeId: e.id,
        employeeName: e.fullName,
        type: type,
        date: day,
        daysUntil: days,
      ));
    }
  }

  for (final e in employees) {
    if (e.status != EmployeeStatus.active) continue;
    addAnnual(e, e.dateOfBirth, ReminderType.birthday);
    addAnnual(e, e.joiningDate, ReminderType.anniversary);
    addExpiry(e, e.cnicExpiry, ReminderType.cnicExpiry);
    addExpiry(e, e.contractEndDate, ReminderType.contractEnd);
  }

  out.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
  return out;
}

/// Live upcoming reminders across all (visible) employees.
final remindersProvider = Provider<List<Reminder>>((ref) {
  final employees = ref.watch(employeesProvider).valueOrNull ?? const [];
  return computeReminders(employees, DateTime.now());
});
