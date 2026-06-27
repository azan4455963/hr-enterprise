import 'package:cloud_firestore/cloud_firestore.dart';

enum AssetStatus { available, assigned, retired }

/// A company asset (laptop, phone, equipment…) that can be assigned to an
/// employee. Stored in the `assets` collection.
class AssetModel {
  const AssetModel({
    required this.id,
    required this.name,
    this.category = 'Equipment',
    this.serialNumber,
    this.assignedToId,
    this.assignedToName,
    this.status = AssetStatus.available,
    this.assignedDate,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final String? serialNumber;
  final String? assignedToId;
  final String? assignedToName;
  final AssetStatus status;
  final DateTime? assignedDate;
  final String? notes;
  final DateTime? createdAt;

  factory AssetModel.fromMap(String id, Map<String, dynamic> map) {
    return AssetModel(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Equipment',
      serialNumber: map['serialNumber'] as String?,
      assignedToId: map['assignedToId'] as String?,
      assignedToName: map['assignedToName'] as String?,
      status: AssetStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? 'available'),
        orElse: () => AssetStatus.available,
      ),
      assignedDate: (map['assignedDate'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'serialNumber': serialNumber,
        'assignedToId': assignedToId,
        'assignedToName': assignedToName,
        'status': status.name,
        'assignedDate': assignedDate,
        'notes': notes,
        'createdAt': createdAt ?? DateTime.now(),
      };

  AssetModel copyWith({
    String? name,
    String? category,
    String? serialNumber,
    String? assignedToId,
    String? assignedToName,
    AssetStatus? status,
    DateTime? assignedDate,
    String? notes,
    bool clearAssignee = false,
  }) {
    return AssetModel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      serialNumber: serialNumber ?? this.serialNumber,
      assignedToId: clearAssignee ? null : (assignedToId ?? this.assignedToId),
      assignedToName:
          clearAssignee ? null : (assignedToName ?? this.assignedToName),
      status: status ?? this.status,
      assignedDate: clearAssignee ? null : (assignedDate ?? this.assignedDate),
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
