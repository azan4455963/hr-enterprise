import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/attendance_qr.dart';
import '../models/attendance_qr_session_model.dart';

class AttendanceQrService {
  AttendanceQrService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.attendanceQrSessionsCollection);

  Future<AttendanceQrSessionModel> createSession({
    required String createdBy,
    String companyId = AppConstants.companyId,
  }) async {
    await _deactivateOldSessions(companyId);
    final token = _uuid.v4();
    final expiresAt = DateTime.now().add(
      const Duration(minutes: AppConstants.qrSessionValidityMinutes),
    );
    final session = AttendanceQrSessionModel(
      id: '',
      sessionToken: token,
      companyId: companyId,
      createdBy: createdBy,
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
    );
    final ref = await _collection.add(session.toMap());
    return AttendanceQrSessionModel(
      id: ref.id,
      sessionToken: token,
      companyId: companyId,
      createdBy: createdBy,
      expiresAt: expiresAt,
      createdAt: session.createdAt,
    );
  }

  Future<void> _deactivateOldSessions(String companyId) async {
    final active = await _collection
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .get();
    for (final doc in active.docs) {
      await doc.reference.update({'isActive': false});
    }
  }

  Future<AttendanceQrSessionModel?> validateToken({
    required String companyId,
    required String sessionToken,
  }) async {
    final snap = await _collection
        .where('companyId', isEqualTo: companyId)
        .where('sessionToken', isEqualTo: sessionToken)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final session =
        AttendanceQrSessionModel.fromMap(snap.docs.first.id, snap.docs.first.data());
    if (!session.isValid) return null;
    return session;
  }

  String buildCheckInQr(AttendanceQrSessionModel session) {
    return AttendanceQrPayload(
      companyId: session.companyId,
      sessionToken: session.sessionToken,
      action: 'IN',
    ).encode();
  }

  String buildCheckOutQr(AttendanceQrSessionModel session) {
    return AttendanceQrPayload(
      companyId: session.companyId,
      sessionToken: session.sessionToken,
      action: 'OUT',
    ).encode();
  }

  Stream<AttendanceQrSessionModel?> watchActiveSession({
    String companyId = AppConstants.companyId,
  }) {
    return _collection
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final session =
          AttendanceQrSessionModel.fromMap(snap.docs.first.id, snap.docs.first.data());
      return session.isValid ? session : null;
    });
  }
}
