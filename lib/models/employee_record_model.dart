import 'package:cloud_firestore/cloud_firestore.dart';

/// One free-form record attached to an employee, stored under
/// `employees/{employeeId}/records/{recordId}`. Holds any custom data —
/// assets, documents, notes, etc. — as a list of label/value fields.
class EmployeeRecordField {
  const EmployeeRecordField({required this.label, required this.value});
  final String label;
  final String value;

  Map<String, dynamic> toMap() => {'label': label, 'value': value};

  factory EmployeeRecordField.fromMap(Map<String, dynamic> m) =>
      EmployeeRecordField(
        label: m['label'] as String? ?? '',
        value: m['value'] as String? ?? '',
      );
}

class EmployeeRecordModel {
  const EmployeeRecordModel({
    required this.id,
    required this.title,
    this.category = 'General',
    this.fields = const [],
    this.note,
    this.visibleToEmployee = false,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String title;
  final String category;
  final List<EmployeeRecordField> fields;
  final String? note;
  final bool visibleToEmployee;
  final DateTime? createdAt;
  final String? createdBy;

  factory EmployeeRecordModel.fromMap(Map<String, dynamic> map, String id) {
    return EmployeeRecordModel(
      id: id,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      fields: (map['fields'] as List? ?? const [])
          .map((f) => EmployeeRecordField.fromMap(
              Map<String, dynamic>.from(f as Map)))
          .toList(),
      note: map['note'] as String?,
      visibleToEmployee: map['visibleToEmployee'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'category': category,
        'fields': [for (final f in fields) f.toMap()],
        'note': note,
        'visibleToEmployee': visibleToEmployee,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };
}
