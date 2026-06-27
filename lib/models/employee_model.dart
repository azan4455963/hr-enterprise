import 'package:equatable/equatable.dart';

class EmployeeModel extends Equatable {
  const EmployeeModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.fatherName,
    this.cnic,
    this.phone,
    this.address,
    this.departmentId,
    this.departmentName,
    this.position,
    this.salary,
    this.joiningDate,
    this.leavingDate,
    this.dateOfBirth,
    this.cnicExpiry,
    this.contractEndDate,
    this.profilePictureUrl,
    this.documentUrls = const [],
    this.status = EmployeeStatus.active,
    this.userId,
    this.companyId = 'default_company',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? fatherName;
  final String? cnic;
  final String? phone;
  final String? address;
  final String? departmentId;
  final String? departmentName;
  final String? position;
  final double? salary;
  final DateTime? joiningDate;
  final DateTime? leavingDate;

  /// Optional reminder dates (used by the Reminders module).
  final DateTime? dateOfBirth;
  final DateTime? cnicExpiry;
  final DateTime? contractEndDate;
  final String? profilePictureUrl;
  final List<String> documentUrls;
  final EmployeeStatus status;
  final String? userId;
  final String companyId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName';

  factory EmployeeModel.fromMap(String id, Map<String, dynamic> map) {
    return EmployeeModel(
      id: id,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fatherName: map['fatherName'] as String?,
      cnic: map['cnic'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      departmentId: map['departmentId'] as String?,
      departmentName: map['departmentName'] as String?,
      position: map['position'] as String?,
      salary: (map['salary'] as num?)?.toDouble(),
      joiningDate: _parseDate(map['joiningDate']),
      leavingDate: _parseDate(map['leavingDate']),
      dateOfBirth: _parseDate(map['dateOfBirth']),
      cnicExpiry: _parseDate(map['cnicExpiry']),
      contractEndDate: _parseDate(map['contractEndDate']),
      profilePictureUrl: map['profilePictureUrl'] as String?,
      documentUrls: List<String>.from(map['documentUrls'] as List? ?? []),
      status: EmployeeStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'active'),
        orElse: () => EmployeeStatus.active,
      ),
      userId: map['userId'] as String?,
      companyId: map['companyId'] as String? ?? 'default_company',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeSalary = true}) {
    final map = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'fatherName': fatherName,
      'cnic': cnic,
      'phone': phone,
      'address': address,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'position': position,
      'joiningDate': joiningDate,
      'leavingDate': leavingDate,
      'dateOfBirth': dateOfBirth,
      'cnicExpiry': cnicExpiry,
      'contractEndDate': contractEndDate,
      'profilePictureUrl': profilePictureUrl,
      'documentUrls': documentUrls,
      'status': status.name,
      'userId': userId,
      'companyId': companyId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (includeSalary) map['salary'] = salary;
    return map;
  }

  EmployeeModel copyWith({
    String? firstName,
    String? lastName,
    String? departmentId,
    String? departmentName,
    double? salary,
    EmployeeStatus? status,
    DateTime? updatedAt,
  }) {
    return EmployeeModel(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      fatherName: fatherName,
      cnic: cnic,
      phone: phone,
      address: address,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      position: position,
      salary: salary ?? this.salary,
      joiningDate: joiningDate,
      leavingDate: leavingDate,
      profilePictureUrl: profilePictureUrl,
      documentUrls: documentUrls,
      status: status ?? this.status,
      userId: userId,
      companyId: companyId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, email, firstName, lastName, departmentId];
}

enum EmployeeStatus { active, inactive, pending, terminated }
