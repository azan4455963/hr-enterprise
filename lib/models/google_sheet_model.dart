import 'package:cloud_firestore/cloud_firestore.dart';

import 'employee_model.dart';

class GoogleSheetModel {
  final String id;
  final String title;
  final String url;
  final String sheetId;
  final String addedBy;
  final DateTime addedAt;
  final int order;

  /// When true, this sheet auto-syncs its rows into the employees collection
  /// on every background refresh.
  final bool syncEmployees;

  GoogleSheetModel({
    required this.id,
    required this.title,
    required this.url,
    required this.sheetId,
    required this.addedBy,
    required this.addedAt,
    required this.order,
    this.syncEmployees = false,
  });

  factory GoogleSheetModel.fromMap(Map<String, dynamic> map, String docId) {
    return GoogleSheetModel(
      id: docId,
      title: map['title'] as String? ?? '',
      url: map['url'] as String? ?? '',
      sheetId: map['sheetId'] as String? ?? '',
      addedBy: map['addedBy'] as String? ?? '',
      addedAt: (map['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      order: map['order'] as int? ?? 0,
      syncEmployees: map['syncEmployees'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'sheetId': sheetId,
      'addedBy': addedBy,
      'addedAt': Timestamp.fromDate(addedAt),
      'order': order,
      'syncEmployees': syncEmployees,
    };
  }

  /// Extract sheet ID from various Google Sheets URL formats.
  ///
  /// Handles both editable links (`/d/{id}/edit`) and published-to-web links
  /// (`/d/e/{pubId}/pubhtml`). Published ids begin with `2PACX-`.
  static String extractSheetId(String url) {
    final trimmed = url.trim();

    // Published-to-web: /d/e/{pubId}/pub... — capture the long 2PACX id.
    final pubMatch = RegExp(r'/d/e/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
    if (pubMatch != null) return pubMatch.group(1)!;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return '';

    // Pattern: /d/{sheetId}/edit or /d/{sheetId}/export etc.
    final segments = uri.pathSegments;
    final dIndex = segments.indexOf('d');
    if (dIndex != -1 && dIndex + 1 < segments.length) {
      return segments[dIndex + 1];
    }

    // Also try direct match from path
    final regex = RegExp(r'/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null) return match.group(1)!;

    return '';
  }
}

/// Count of rows for each distinct value within one status column.
class SheetStatusBreakdown {
  final String column;
  final Map<String, int> counts;
  final int blank;

  const SheetStatusBreakdown({
    required this.column,
    required this.counts,
    this.blank = 0,
  });

  /// Distinct values sorted by descending count.
  List<MapEntry<String, int>> get sortedCounts {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  int get filled => counts.values.fold(0, (s, v) => s + v);
}

/// Auto-computed dashboard summary for a single attached sheet.
class SheetSummary {
  final String sheetId;
  final String title;
  final int totalRows;
  final List<SheetStatusBreakdown> breakdowns;
  final String? error;

  const SheetSummary({
    required this.sheetId,
    required this.title,
    required this.totalRows,
    required this.breakdowns,
    this.error,
  });

  factory SheetSummary.error(GoogleSheetModel sheet, String message) {
    return SheetSummary(
      sheetId: sheet.sheetId,
      title: sheet.title,
      totalRows: 0,
      breakdowns: const [],
      error: message,
    );
  }

  bool get hasError => error != null;
}

/// Attendance figures auto-extracted from an attendance-style sheet.
class AttendanceSheetSummary {
  final String sheetTitle;
  final int present;
  final int absent;
  final int leave;
  final int other;

  /// Headcount (number of people), distinct from present/absent day totals.
  final int headcount;

  /// e.g. "Jun 2026" when the figures are a monthly total, else null (daily).
  final String? periodLabel;

  /// Department derived from the sheet title (e.g. "IT", "Billing").
  final String department;

  const AttendanceSheetSummary({
    required this.sheetTitle,
    required this.present,
    required this.absent,
    required this.leave,
    this.other = 0,
    this.headcount = 0,
    this.periodLabel,
    this.department = '',
  });

  int get total => present + absent + leave + other;

  double get presentRate {
    final base = present + absent + leave;
    return base == 0 ? 0 : present / base;
  }
}

/// Result of parsing a sheet into employee records (before saving).
class SheetEmployeeImport {
  final List<EmployeeModel> employees;
  final int skippedRows;

  const SheetEmployeeImport({
    required this.employees,
    required this.skippedRows,
  });

  bool get isEmpty => employees.isEmpty;
  int get count => employees.length;
}

/// Rows from one sheet that matched a person (by name or email).
class SheetMatch {
  final String sheetTitle;
  final List<Map<String, String>> records;

  const SheetMatch({required this.sheetTitle, required this.records});
}
