import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// A spreadsheet discovered inside a linked Drive folder.
class DriveSpreadsheet {
  final String id;
  final String name;
  const DriveSpreadsheet({required this.id, required this.name});
}

/// Connects to Google Drive (OAuth) and reads spreadsheets inside folders.
///
/// Requires a Google Cloud OAuth Client ID (see docs/DRIVE_SETUP.md) and the
/// Drive + Sheets APIs enabled. Until that is configured, [connect] will fail.
class DriveService {
  DriveService();

  // Built lazily — constructing GoogleSignIn on web needs a client ID, so we
  // only create it when the user taps Connect.
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn(
        scopes: const [
          'https://www.googleapis.com/auth/drive.readonly',
          'https://www.googleapis.com/auth/spreadsheets.readonly',
        ],
      );
  GoogleSignInAccount? _account;

  bool get isConnected => _account != null;
  String? get connectedEmail => _account?.email;

  /// Interactive sign-in. Returns true if the user granted access.
  Future<bool> connect() async {
    _account = await _googleSignIn.signIn();
    return _account != null;
  }

  Future<void> disconnect() async {
    await _googleSignIn.signOut();
    _account = null;
  }

  Future<Map<String, String>> _authHeaders() async {
    _account ??= await _googleSignIn.signInSilently();
    final account = _account;
    if (account == null) {
      throw Exception('Not connected to Google Drive. Tap "Connect" first.');
    }
    return account.authHeaders;
  }

  /// List all Google Sheets inside a Drive folder.
  Future<List<DriveSpreadsheet>> listSpreadsheets(String folderId) async {
    final headers = await _authHeaders();
    final q = Uri.encodeQueryComponent(
      "'$folderId' in parents and "
      "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
    );
    final url = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?q=$q&fields=files(id,name)&pageSize=1000',
    );

    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Drive list failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final files = (data['files'] as List? ?? []);
    return files
        .map((f) => DriveSpreadsheet(
              id: f['id'] as String? ?? '',
              name: f['name'] as String? ?? 'Untitled',
            ))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  /// Export a spreadsheet's first tab as CSV text.
  Future<String> readSpreadsheetCsv(String fileId) async {
    final headers = await _authHeaders();
    final url = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId/export'
      '?mimeType=text/csv',
    );
    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Drive export failed (${res.statusCode})');
    }
    return res.body;
  }
}
