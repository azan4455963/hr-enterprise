import 'package:cloud_firestore/cloud_firestore.dart';

/// A company department (IT, Marketing, Billing…). Only the company admin can
/// create/rename/delete these. [directorIds] are the users who manage this
/// department (assigned by the admin).
class DepartmentModel {
  final String id;
  final String name;
  final String? description;
  final List<String> directorIds;
  final DateTime? createdAt;
  final String? createdBy;

  DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    this.directorIds = const [],
    this.createdAt,
    this.createdBy,
  });

  factory DepartmentModel.fromMap(Map<String, dynamic> map, String docId) {
    return DepartmentModel(
      id: docId,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      directorIds: List<String>.from(map['directorIds'] as List? ?? const []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'directorIds': directorIds,
        'createdAt': createdAt ?? DateTime.now(),
        'createdBy': createdBy,
      };
}
