import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/theme/app_colors.dart';
import '../../drive/screens/google_drive_admin_screen.dart';
import 'google_sheets_admin_screen.dart';

/// One menu holding Google Sheets and Google Drive as two tabs.
class SheetsDriveHubScreen extends StatefulWidget {
  const SheetsDriveHubScreen({super.key});

  @override
  State<SheetsDriveHubScreen> createState() => _SheetsDriveHubScreenState();
}

class _SheetsDriveHubScreenState extends State<SheetsDriveHubScreen> {
  int _tab = 0;

  static const _labels = ['Google Sheets', 'Google Drive'];
  static const _icons = [Icons.table_chart_rounded, Icons.cloud_rounded];

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.canvas,
          padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, 16, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (var i = 0; i < _labels.length; i++) _pill(i)],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              GoogleSheetsAdminScreen(embedded: true),
              GoogleDriveAdminScreen(embedded: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(int i) {
    final selected = _tab == i;
    return InkWell(
      onTap: () => setState(() => _tab = i),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandNavy : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.brandNavy : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[i],
                size: 17,
                color: selected ? Colors.white : AppColors.textBody),
            const SizedBox(width: 7),
            Text(
              _labels[i],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
