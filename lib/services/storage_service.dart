import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  Future<String> uploadBytes({
    required String folder,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final path = '$folder/${_uuid.v4()}_$fileName';
    final ref = _storage.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType ?? 'application/octet-stream'),
    );
    return ref.getDownloadURL();
  }

  Future<String> uploadProfilePhoto(String employeeId, Uint8List bytes) {
    return uploadBytes(
      folder: 'employees/$employeeId/profile',
      bytes: bytes,
      fileName: 'profile.jpg',
      contentType: 'image/jpeg',
    );
  }

  Future<String> uploadDocument(String employeeId, Uint8List bytes, String name) {
    return uploadBytes(
      folder: 'employees/$employeeId/documents',
      bytes: bytes,
      fileName: name,
    );
  }

  Future<String> uploadOnboardingFile(
    String submissionId,
    Uint8List bytes,
    String name,
  ) {
    return uploadBytes(
      folder: 'onboarding/$submissionId',
      bytes: bytes,
      fileName: name,
    );
  }

  /// Best-effort delete of a stored file given its download URL.
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {/* file may already be gone — ignore */}
  }
}
