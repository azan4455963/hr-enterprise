import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_exception.dart';
import '../utils/file_saver.dart';

/// MIME type for .xlsx downloads.
const kXlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Save Excel bytes as an .xlsx download (web) / share sheet (native).
Future<void> saveXlsxBytes(Uint8List bytes, String filename) =>
    saveBytes(bytes, filename, mimeType: kXlsxMime);

/// A compact "Export ▾" button that offers PDF and/or Excel download from a
/// dropdown. Handles its own busy state and surfaces errors via a SnackBar, so
/// each screen only supplies the export closures. Used in module headers
/// (Attendance, Employees, Payroll, Leave) to mirror the Reports page exports.
class ExportMenuButton extends StatefulWidget {
  const ExportMenuButton({
    super.key,
    this.onExportPdf,
    required this.onExportExcel,
    this.label = 'Export',
  });

  /// Runs the PDF export. Null hides the PDF option.
  final Future<void> Function()? onExportPdf;

  /// Runs the Excel export.
  final Future<void> Function() onExportExcel;

  final String label;

  @override
  State<ExportMenuButton> createState() => _ExportMenuButtonState();
}

class _ExportMenuButtonState extends State<ExportMenuButton> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !_busy,
      tooltip: 'Export',
      // Force a white menu with dark text so it stays readable in dark mode.
      color: AppColors.surface,
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'pdf' && widget.onExportPdf != null) {
          _run(widget.onExportPdf!);
        } else if (v == 'excel') {
          _run(widget.onExportExcel);
        }
      },
      itemBuilder: (_) => [
        if (widget.onExportPdf != null)
          const PopupMenuItem(
            value: 'pdf',
            child: _MenuRow(
              icon: Icons.picture_as_pdf_outlined,
              color: AppColors.pillRedFg,
              label: 'Export as PDF',
            ),
          ),
        const PopupMenuItem(
          value: 'excel',
          child: _MenuRow(
            icon: Icons.table_chart_outlined,
            color: AppColors.pillGreenFg,
            label: 'Export as Excel',
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.download_rounded,
                  size: 18, color: AppColors.brandNavy),
            const SizedBox(width: 8),
            Text(
              _busy ? 'Exporting…' : widget.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.brandNavy,
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                size: 20, color: AppColors.brandNavy),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody)),
      ],
    );
  }
}
