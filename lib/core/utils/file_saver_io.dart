import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native (Windows / Android / iOS / macOS / Linux): write the bytes to a temp
/// file, then open the system share sheet so the user can save or send it.
Future<void> saveBytes(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    text: filename,
  );
}
