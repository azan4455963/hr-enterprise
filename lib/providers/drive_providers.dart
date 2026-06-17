import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drive_link_model.dart';
import '../models/google_sheet_model.dart';
import '../services/drive_links_service.dart';
import '../services/drive_service.dart';
import 'google_sheets_providers.dart';

final driveLinksServiceProvider = Provider<DriveLinksService>((ref) {
  return DriveLinksService();
});

/// Stream of all linked Google Drive folders, ordered.
final driveLinksProvider = StreamProvider<List<DriveLinkModel>>((ref) {
  return ref.watch(driveLinksServiceProvider).watchLinks();
});

final driveServiceProvider = Provider<DriveService>((ref) {
  return DriveService();
});

/// Whether the admin has connected Google Drive in this session.
final driveConnectedProvider = StateProvider<bool>((ref) {
  return ref.watch(driveServiceProvider).isConnected;
});

/// All matching rows for a person, gathered from every spreadsheet inside the
/// linked Drive folders (matched by name OR email). Empty when Drive is not
/// connected or no folders are linked.
final driveSheetRecordsProvider = FutureProvider.family<List<SheetMatch>,
    ({String name, String email})>((ref, key) async {
  ref.watch(sheetsAutoRefreshProvider);

  final connected = ref.watch(driveConnectedProvider);
  if (!connected) return [];

  final links = await ref.watch(driveLinksProvider.future);
  if (links.isEmpty) return [];

  final drive = ref.watch(driveServiceProvider);
  final sheetsService = ref.watch(googleSheetsServiceProvider);

  final matches = <SheetMatch>[];
  for (final link in links) {
    try {
      final files = await drive.listSpreadsheets(link.folderId);
      for (final file in files) {
        try {
          final csv = await drive.readSpreadsheetCsv(file.id);
          final rows = sheetsService.parseCsv(csv);
          final found = sheetsService.findRowsFor(
            rows: rows,
            name: key.name,
            email: key.email,
          );
          if (found.isNotEmpty) {
            matches.add(SheetMatch(
              sheetTitle: '${link.label} / ${file.name}',
              records: found,
            ));
          }
        } catch (_) {
          // Skip a single sheet that fails to read.
        }
      }
    } catch (_) {
      // Skip a folder that fails to list.
    }
  }
  return matches;
});
