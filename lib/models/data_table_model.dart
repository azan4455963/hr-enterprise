import 'package:cloud_firestore/cloud_firestore.dart';

/// A custom, in-app data table (like a mini spreadsheet) — e.g. an attendance
/// grid. Stores its own columns and rows. Firestore can't nest arrays, so each
/// row is saved as a map `{ 'cells': [...] }`.
class DataTableModel {
  final String id;
  final String name;
  final List<String> columns;
  final List<List<String>> rows;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DataTableModel({
    required this.id,
    required this.name,
    this.columns = const [],
    this.rows = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory DataTableModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawRows = (map['rows'] as List? ?? const []);
    return DataTableModel(
      id: docId,
      name: map['name'] as String? ?? '',
      columns: List<String>.from(map['columns'] as List? ?? const []),
      rows: rawRows
          .map<List<String>>((r) =>
              List<String>.from((r as Map)['cells'] as List? ?? const []))
          .toList(),
      createdBy: map['createdBy'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'columns': columns,
        'rows': [
          for (final r in rows) {'cells': r},
        ],
        'createdBy': createdBy,
        'createdAt': createdAt ?? DateTime.now(),
        'updatedAt': DateTime.now(),
      };
}
