import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/drive_link_model.dart';

/// CRUD for linked Google Drive folders (collection `drive_links`).
class DriveLinksService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('drive_links');

  Stream<List<DriveLinkModel>> watchLinks() {
    return _ref.orderBy('order').snapshots().map(
          (snap) => snap.docs
              .map((d) => DriveLinkModel.fromMap(
                    d.data() as Map<String, dynamic>,
                    d.id,
                  ))
              .toList(),
        );
  }

  Future<void> addLink({
    required String label,
    required String url,
    required String addedBy,
  }) async {
    final folderId = DriveLinkModel.extractFolderId(url);
    if (folderId.isEmpty) {
      throw Exception(
        'Invalid Google Drive folder link. '
        'Use a link like https://drive.google.com/drive/folders/...',
      );
    }
    final count = await _ref.get().then((s) => s.docs.length);
    await _ref.add({
      'label': label,
      'url': url,
      'folderId': folderId,
      'addedBy': addedBy,
      'addedAt': Timestamp.now(),
      'order': count,
    });
  }

  Future<void> deleteLink(String docId) async {
    await _ref.doc(docId).delete();
  }
}
