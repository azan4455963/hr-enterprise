import 'package:equatable/equatable.dart';

enum OnboardingLinkStatus { active, expired, used, revoked }

enum OnboardingSubmissionStatus { draft, submitted, approved, rejected }

class OnboardingLinkModel extends Equatable {
  const OnboardingLinkModel({
    required this.id,
    required this.token,
    required this.createdBy,
    this.title = 'Employee Onboarding',
    this.expiresAt,
    this.status = OnboardingLinkStatus.active,
    this.maxUses = 1,
    this.usedCount = 0,
    this.createdAt,
  });

  final String id;
  final String token;
  final String createdBy;
  final String title;
  final DateTime? expiresAt;
  final OnboardingLinkStatus status;
  final int maxUses;
  final int usedCount;
  final DateTime? createdAt;

  bool get isValid {
    if (status != OnboardingLinkStatus.active) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    if (usedCount >= maxUses) return false;
    return true;
  }

  String get shareUrl => 'https://hr-enterprise.app/onboard/$token';

  factory OnboardingLinkModel.fromMap(String id, Map<String, dynamic> map) {
    return OnboardingLinkModel(
      id: id,
      token: map['token'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      title: map['title'] as String? ?? 'Employee Onboarding',
      expiresAt: _parseDate(map['expiresAt']),
      status: OnboardingLinkStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'active'),
        orElse: () => OnboardingLinkStatus.active,
      ),
      maxUses: map['maxUses'] as int? ?? 1,
      usedCount: map['usedCount'] as int? ?? 0,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'token': token,
        'createdBy': createdBy,
        'title': title,
        'expiresAt': expiresAt,
        'status': status.name,
        'maxUses': maxUses,
        'usedCount': usedCount,
        'createdAt': createdAt ?? DateTime.now(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, token, status];
}

class OnboardingSubmissionModel extends Equatable {
  const OnboardingSubmissionModel({
    required this.id,
    required this.linkId,
    this.firstName,
    this.lastName,
    this.fatherName,
    this.cnic,
    this.phone,
    this.email,
    this.address,
    this.department,
    this.position,
    this.profilePictureUrl,
    this.documentUrls = const [],
    this.currentStep = 0,
    this.status = OnboardingSubmissionStatus.draft,
    this.reviewedBy,
    this.reviewNotes,
    this.createdAt,
    this.submittedAt,
  });

  final String id;
  final String linkId;
  final String? firstName;
  final String? lastName;
  final String? fatherName;
  final String? cnic;
  final String? phone;
  final String? email;
  final String? address;
  final String? department;
  final String? position;
  final String? profilePictureUrl;
  final List<String> documentUrls;
  final int currentStep;
  final OnboardingSubmissionStatus status;
  final String? reviewedBy;
  final String? reviewNotes;
  final DateTime? createdAt;
  final DateTime? submittedAt;

  factory OnboardingSubmissionModel.fromMap(String id, Map<String, dynamic> map) {
    return OnboardingSubmissionModel(
      id: id,
      linkId: map['linkId'] as String? ?? '',
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      fatherName: map['fatherName'] as String?,
      cnic: map['cnic'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      department: map['department'] as String?,
      position: map['position'] as String?,
      profilePictureUrl: map['profilePictureUrl'] as String?,
      documentUrls: List<String>.from(map['documentUrls'] as List? ?? []),
      currentStep: map['currentStep'] as int? ?? 0,
      status: OnboardingSubmissionStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'draft'),
        orElse: () => OnboardingSubmissionStatus.draft,
      ),
      reviewedBy: map['reviewedBy'] as String?,
      reviewNotes: map['reviewNotes'] as String?,
      createdAt: _parseDate(map['createdAt']),
      submittedAt: _parseDate(map['submittedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'linkId': linkId,
        'firstName': firstName,
        'lastName': lastName,
        'fatherName': fatherName,
        'cnic': cnic,
        'phone': phone,
        'email': email,
        'address': address,
        'department': department,
        'position': position,
        'profilePictureUrl': profilePictureUrl,
        'documentUrls': documentUrls,
        'currentStep': currentStep,
        'status': status.name,
        'reviewedBy': reviewedBy,
        'reviewNotes': reviewNotes,
        'createdAt': createdAt ?? DateTime.now(),
        'submittedAt': submittedAt,
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, linkId, status];
}
