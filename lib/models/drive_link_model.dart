import 'package:cloud_firestore/cloud_firestore.dart';

/// A linked Google Drive folder. The app can list spreadsheets inside it
/// (once Drive access is connected) and feed their rows into employee search.
class DriveLinkModel {
  final String id;
  final String label;
  final String url;
  final String folderId;
  final String addedBy;
  final DateTime addedAt;
  final int order;

  DriveLinkModel({
    required this.id,
    required this.label,
    required this.url,
    required this.folderId,
    required this.addedBy,
    required this.addedAt,
    required this.order,
  });

  factory DriveLinkModel.fromMap(Map<String, dynamic> map, String docId) {
    return DriveLinkModel(
      id: docId,
      label: map['label'] as String? ?? '',
      url: map['url'] as String? ?? '',
      folderId: map['folderId'] as String? ?? '',
      addedBy: map['addedBy'] as String? ?? '',
      addedAt: (map['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      order: map['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'url': url,
        'folderId': folderId,
        'addedBy': addedBy,
        'addedAt': Timestamp.fromDate(addedAt),
        'order': order,
      };

  /// Extract a folder ID from common Google Drive folder URL formats:
  ///  • `https://drive.google.com/drive/folders/{id}`
  ///  • `https://drive.google.com/drive/u/0/folders/{id}`
  ///  • `https://drive.google.com/open?id={id}`
  static String extractFolderId(String url) {
    final trimmed = url.trim();

    final folderMatch =
        RegExp(r'/folders/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
    if (folderMatch != null) return folderMatch.group(1)!;

    final uri = Uri.tryParse(trimmed);
    final idParam = uri?.queryParameters['id'];
    if (idParam != null && idParam.isNotEmpty) return idParam;

    return '';
  }
}
