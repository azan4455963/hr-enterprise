import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/company_settings_model.dart';

class CompanySettingsService {
  CompanySettingsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(AppConstants.companySettingsCollection)
      .doc(AppConstants.companyId);

  Stream<CompanySettingsModel> watchSettings() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return CompanySettingsModel.defaults(AppConstants.companyId);
      return CompanySettingsModel.fromMap(snap.id, snap.data()!);
    });
  }

  Future<CompanySettingsModel> getSettings() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      final defaults = CompanySettingsModel.defaults(AppConstants.companyId);
      await _doc.set(defaults.toMap());
      return defaults;
    }
    return CompanySettingsModel.fromMap(snap.id, snap.data()!);
  }

  Future<void> updateSettings(CompanySettingsModel settings) async {
    await _doc.set(settings.toMap(), SetOptions(merge: true));
  }
}
