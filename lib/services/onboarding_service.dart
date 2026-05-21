import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../models/employee_model.dart';
import '../models/onboarding_model.dart';
import 'employee_service.dart';

class OnboardingService {
  OnboardingService({
    FirebaseFirestore? firestore,
    EmployeeService? employeeService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _employeeService = employeeService ?? EmployeeService();

  final FirebaseFirestore _firestore;
  final EmployeeService _employeeService;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _links =>
      _firestore.collection(AppConstants.onboardingCollection);

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection(AppConstants.onboardingSubmissionsCollection);

  Stream<List<OnboardingLinkModel>> watchLinks() {
    return _links
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OnboardingLinkModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<OnboardingSubmissionModel>> watchSubmissions() {
    return _submissions
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OnboardingSubmissionModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<OnboardingLinkModel> createLink({
    required String createdBy,
    String title = 'Employee Onboarding',
    int expiryDays = AppConstants.onboardingLinkExpiryDays,
  }) async {
    final token = _uuid.v4();
    final link = OnboardingLinkModel(
      id: '',
      token: token,
      createdBy: createdBy,
      title: title,
      expiresAt: DateTime.now().add(Duration(days: expiryDays)),
      createdAt: DateTime.now(),
    );
    final ref = await _links.add(link.toMap());
    return OnboardingLinkModel(
      id: ref.id,
      token: token,
      createdBy: createdBy,
      title: title,
      expiresAt: link.expiresAt,
      createdAt: link.createdAt,
    );
  }

  Future<OnboardingLinkModel?> getLinkByToken(String token) async {
    final snap = await _links.where('token', isEqualTo: token).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return OnboardingLinkModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<String> saveDraft(OnboardingSubmissionModel submission) async {
    final data = submission.toMap();
    if (submission.id.isEmpty) {
      final ref = await _submissions.add(data);
      return ref.id;
    }
    await _submissions.doc(submission.id).set(data, SetOptions(merge: true));
    return submission.id;
  }

  Future<void> submitApplication(OnboardingSubmissionModel submission) async {
    final data = submission.toMap();
    data['status'] = OnboardingSubmissionStatus.submitted.name;
    data['submittedAt'] = DateTime.now();
    if (submission.id.isEmpty) {
      await _submissions.add(data);
    } else {
      await _submissions.doc(submission.id).update(data);
    }
    await _links.doc(submission.linkId).update({
      'usedCount': FieldValue.increment(1),
    });
  }

  Future<void> approveSubmission(
    OnboardingSubmissionModel submission,
    String reviewedBy,
  ) async {
    final employee = EmployeeModel(
      id: '',
      firstName: submission.firstName ?? '',
      lastName: submission.lastName ?? '',
      email: submission.email ?? '',
      fatherName: submission.fatherName,
      cnic: submission.cnic,
      phone: submission.phone,
      address: submission.address,
      departmentName: submission.department,
      position: submission.position,
      profilePictureUrl: submission.profilePictureUrl,
      documentUrls: submission.documentUrls,
      status: EmployeeStatus.active,
      joiningDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _employeeService.createEmployee(employee, userId: reviewedBy);
    await _submissions.doc(submission.id).update({
      'status': OnboardingSubmissionStatus.approved.name,
      'reviewedBy': reviewedBy,
    });
  }

  Future<void> rejectSubmission(
    String submissionId,
    String reviewedBy, {
    String? notes,
  }) async {
    await _submissions.doc(submissionId).update({
      'status': OnboardingSubmissionStatus.rejected.name,
      'reviewedBy': reviewedBy,
      'reviewNotes': notes,
    });
  }
}
