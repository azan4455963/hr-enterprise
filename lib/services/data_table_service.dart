import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/data_table_model.dart';
import 'audit_service.dart';

/// Default columns for a Salary Workbook (admin can rename / add / delete).
const List<String> kSalaryWorkbookColumns = [
  'Source',
  'Employee Name',
  'Branch Code',
  'Account Number',
  'Basic Salary',
  'Leave Deduction',
  'Travelling/Bonuses/Increment',
  'Gross Salary',
  'Medical Allowance 10%',
  'Taxable Income',
  'Tax',
  'Advance Salary',
  'Loan Deduction',
  'Net Salary',
  'Reason',
  'Deductions',
  'Bonus Cash Paid',
  'Additional',
];

/// CRUD for custom in-app data tables (`data_tables`). A table is a workbook of
/// one or more [DataSheet] tabs.
class DataTableService {
  DataTableService({FirebaseFirestore? firestore, AuditService? audit})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final AuditService _audit;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('data_tables');

  /// All tables (admin). When [departmentNames] is given (a director), only
  /// tables tagged to one of those departments are returned (sorted client-side
  /// to avoid a composite index).
  Stream<List<DataTableModel>> watchTables({List<String>? departmentNames}) {
    if (departmentNames != null) {
      if (departmentNames.isEmpty) {
        return Stream.value(const <DataTableModel>[]);
      }
      final scoped = departmentNames.take(30).toList();
      return _ref
          .where('departmentName', whereIn: scoped)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => DataTableModel.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0))));
    }
    return _ref.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => DataTableModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Stream<DataTableModel?> watchTable(String id) {
    return _ref.doc(id).snapshots().map(
        (d) => d.exists ? DataTableModel.fromMap(d.data()!, d.id) : null);
  }

  /// Plain table with a single empty sheet.
  Future<String> create({
    required String name,
    required String userId,
    String? departmentName,
    List<String> columns = const ['Column 1'],
  }) async {
    final sheet = DataSheet(name: 'Sheet 1', columns: columns, rows: const []);
    final ref = await _ref.add({
      'name': name.trim(),
      'sheets': [sheet.toMap()],
      'createdBy': userId,
      'departmentName': ?departmentName,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'tables',
      targetId: ref.id,
      details: {'name': name},
    );
    return ref.id;
  }

  /// Attendance workbook: 12 month tabs (Jan–Dec of [year]); each tab is a
  /// matrix pre-filled with that month's dates (col A) and day names (col B).
  /// The user then adds employee columns and fills the status cells.
  Future<String> createAttendanceWorkbook({
    required String name,
    required int year,
    required String userId,
    String? departmentName,
  }) async {
    final dateFmt = DateFormat('dd-MMM-yyyy');
    final dayFmt = DateFormat('EEEE');
    final sheets = <Map<String, dynamic>>[];
    for (var m = 1; m <= 12; m++) {
      final daysInMonth = DateTime(year, m + 1, 0).day;
      final rows = <List<String>>[];
      for (var d = 1; d <= daysInMonth; d++) {
        final date = DateTime(year, m, d);
        rows.add([dateFmt.format(date), dayFmt.format(date)]);
      }
      sheets.add(DataSheet(
        name: DateFormat('MMMM').format(DateTime(year, m)),
        columns: const ['Date', 'Working Days'],
        rows: rows,
      ).toMap());
    }
    final ref = await _ref.add({
      'name': name.trim(),
      'sheets': sheets,
      'createdBy': userId,
      'departmentName': ?departmentName,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'tables',
      targetId: ref.id,
      details: {'name': name, 'type': 'attendance', 'year': year},
    );
    return ref.id;
  }

  /// Create a brand-new table from imported sheets (e.g. an uploaded .xlsx).
  /// Never touches existing tables.
  Future<String> importWorkbook({
    required String name,
    required List<DataSheet> sheets,
    required String userId,
    String? departmentName,
  }) async {
    final safeSheets = sheets.isEmpty
        ? [const DataSheet(name: 'Sheet 1', columns: ['Column 1'], rows: [])]
        : sheets;
    final ref = await _ref.add({
      'name': name.trim().isEmpty ? 'Imported table' : name.trim(),
      'sheets': [for (final s in safeSheets) s.toMap()],
      'createdBy': userId,
      'departmentName': ?departmentName,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'tables',
      targetId: ref.id,
      details: {'name': name, 'type': 'import', 'tabs': safeSheets.length},
    );
    return ref.id;
  }

  /// Salary workbook: 12 month tabs (Jan–Dec of [year]), each pre-set with the
  /// salary columns and some empty rows to fill (one row per employee).
  Future<String> createSalaryWorkbook({
    required String name,
    required int year,
    required String userId,
    String? departmentName,
  }) async {
    final sheets = <Map<String, dynamic>>[];
    for (var m = 1; m <= 12; m++) {
      sheets.add(DataSheet(
        name: DateFormat('MMMM').format(DateTime(year, m)),
        columns: kSalaryWorkbookColumns,
        rows: List.generate(
            12, (_) => List<String>.filled(kSalaryWorkbookColumns.length, '')),
      ).toMap());
    }
    final ref = await _ref.add({
      'name': name.trim(),
      'sheets': sheets,
      'createdBy': userId,
      'departmentName': ?departmentName,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'create',
      module: 'tables',
      targetId: ref.id,
      details: {'name': name, 'type': 'salary', 'year': year},
    );
    return ref.id;
  }

  /// Save the whole workbook (all tabs). Optionally also renames it.
  Future<void> save(
    String id, {
    String? name,
    required List<DataSheet> sheets,
    required String userId,
  }) async {
    await _ref.doc(id).update({
      if (name != null) 'name': name.trim(),
      'sheets': [for (final s in sheets) s.toMap()],
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'tables',
      targetId: id,
    );
  }

  /// Assign (or clear, with null) a table's department. Tagging an untagged
  /// table to a department makes it visible to that department's director.
  Future<void> setDepartment(String id,
      {String? departmentName, required String userId}) async {
    await _ref.doc(id).update({
      'departmentName': departmentName,
      'updatedAt': DateTime.now(),
    });
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'tables',
      targetId: id,
      details: {'departmentName': departmentName},
    );
  }

  Future<void> rename(String id,
      {required String name, required String userId}) async {
    await _ref
        .doc(id)
        .update({'name': name.trim(), 'updatedAt': DateTime.now()});
    await _audit.log(
      userId: userId,
      action: 'update',
      module: 'tables',
      targetId: id,
      details: {'name': name},
    );
  }

  Future<void> delete(String id, {required String userId}) async {
    await _ref.doc(id).delete();
    await _audit.log(
      userId: userId,
      action: 'delete',
      module: 'tables',
      targetId: id,
    );
  }
}
