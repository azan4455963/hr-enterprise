import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../models/data_table_model.dart';

/// Decode an uploaded .xlsx file into our [DataSheet] tabs. Each worksheet
/// becomes a tab; the first row is treated as column headers. Empty trailing
/// columns and fully-empty rows are dropped. Throws if the bytes aren't a
/// readable spreadsheet.
List<DataSheet> parseExcelWorkbook(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheets = <DataSheet>[];

  for (final entry in excel.tables.entries) {
    final rows = entry.value.rows;
    if (rows.isEmpty) continue;

    final header = [for (final c in rows.first) _cell(c?.value)];
    var colCount = header.length;
    while (colCount > 0 && header[colCount - 1].trim().isEmpty) {
      colCount--;
    }
    if (colCount == 0) continue; // no usable header row

    final columns = [
      for (var i = 0; i < colCount; i++)
        header[i].trim().isEmpty ? 'Column ${i + 1}' : header[i].trim(),
    ];

    final dataRows = <List<String>>[];
    for (final r in rows.skip(1)) {
      final cells = [
        for (var i = 0; i < colCount; i++)
          i < r.length ? _cell(r[i]?.value) : '',
      ];
      if (cells.every((c) => c.trim().isEmpty)) continue; // skip blank rows
      dataRows.add(cells);
    }

    sheets.add(DataSheet(
      name: entry.key,
      columns: columns,
      rows: dataRows,
    ));
  }
  return sheets;
}

/// Every CellValue subtype has a clean toString() (text spans concatenate to
/// plain text, numbers/bools/dates stringify sensibly), so this is universal.
String _cell(CellValue? value) => value?.toString() ?? '';
