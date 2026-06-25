import 'package:cloud_firestore/cloud_firestore.dart';

/// A file attached to an employee, stored in Firebase Storage with its
/// metadata under `employees/{employeeId}/documents/{docId}`.
class EmployeeDocumentModel {
  const EmployeeDocumentModel({
    required this.id,
    required this.name,
    required this.url,
    this.category = 'General',
    this.contentType,
    this.size,
    this.uploadedAt,
    this.uploadedBy,
  });

  final String id;
  final String name;
  final String url;
  final String category;
  final String? contentType;
  final int? size;
  final DateTime? uploadedAt;
  final String? uploadedBy;

  factory EmployeeDocumentModel.fromMap(Map<String, dynamic> map, String id) {
    return EmployeeDocumentModel(
      id: id,
      name: map['name'] as String? ?? 'file',
      url: map['url'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      contentType: map['contentType'] as String?,
      size: (map['size'] as num?)?.toInt(),
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate(),
      uploadedBy: map['uploadedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'category': category,
        'contentType': contentType,
        'size': size,
        'uploadedAt': uploadedAt ?? FieldValue.serverTimestamp(),
        'uploadedBy': uploadedBy,
      };

  String get sizeLabel {
    final s = size ?? 0;
    if (s <= 0) return '';
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(0)} KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
