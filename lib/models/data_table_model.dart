import 'package:cloud_firestore/cloud_firestore.dart';

/// One sheet/tab within a table — its own columns and rows. Firestore can't
/// nest arrays, so each row is stored as a map `{ 'cells': [...] }`.
class DataSheet {
  final String name;
  final List<String> columns;
  final List<List<String>> rows;

  const DataSheet({
    required this.name,
    this.columns = const [],
    this.rows = const [],
  });

  DataSheet copyWith({
    String? name,
    List<String>? columns,
    List<List<String>>? rows,
  }) =>
      DataSheet(
        name: name ?? this.name,
        columns: columns ?? this.columns,
        rows: rows ?? this.rows,
      );

  factory DataSheet.fromMap(Map<String, dynamic> m) {
    final rawRows = (m['rows'] as List? ?? const []);
    return DataSheet(
      name: m['name'] as String? ?? 'Sheet',
      columns: List<String>.from(m['columns'] as List? ?? const []),
      rows: rawRows
          .map<List<String>>(
              (r) => List<String>.from((r as Map)['cells'] as List? ?? const []))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'columns': columns,
        'rows': [
          for (final r in rows) {'cells': r},
        ],
      };
}

/// A custom, in-app data table (a mini spreadsheet workbook). Holds one or more
/// [DataSheet] tabs (e.g. one per month for a department's attendance).
class DataTableModel {
  final String id;
  final String name;
  final List<DataSheet> sheets;
  final String? createdBy;
  /// Department this table belongs to. A director only sees tables tagged to a
  /// department they manage; null means company-wide (admin-only).
  final String? departmentName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DataTableModel({
    required this.id,
    required this.name,
    this.sheets = const [],
    this.createdBy,
    this.departmentName,
    this.createdAt,
    this.updatedAt,
  });

  /// Convenience: first sheet's columns/rows (keeps older call-sites working).
  List<String> get columns => sheets.isNotEmpty ? sheets.first.columns : const [];
  List<List<String>> get rows =>
      sheets.isNotEmpty ? sheets.first.rows : const [];

  factory DataTableModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawSheets = map['sheets'] as List?;
    final List<DataSheet> sheets;
    if (rawSheets != null && rawSheets.isNotEmpty) {
      sheets = rawSheets
          .map((s) => DataSheet.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList();
    } else {
      // Legacy single-sheet table → wrap as one tab.
      final rawRows = (map['rows'] as List? ?? const []);
      sheets = [
        DataSheet(
          name: 'Sheet 1',
          columns: List<String>.from(map['columns'] as List? ?? const []),
          rows: rawRows
              .map<List<String>>((r) =>
                  List<String>.from((r as Map)['cells'] as List? ?? const []))
              .toList(),
        ),
      ];
    }
    return DataTableModel(
      id: docId,
      name: map['name'] as String? ?? '',
      sheets: sheets,
      createdBy: map['createdBy'] as String?,
      departmentName: map['departmentName'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'sheets': [for (final s in sheets) s.toMap()],
        'createdBy': createdBy,
        'departmentName': ?departmentName,
        'createdAt': createdAt ?? DateTime.now(),
        'updatedAt': DateTime.now(),
      };
}
