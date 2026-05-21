import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/app_exception.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) throw AppException('Not signed in.');
      final settings = await ref.read(companySettingsProvider.future);
      await ref.read(attendanceServiceProvider).processQrScan(
            uid: user.id,
            rawQr: barcode,
            employeeName: user.displayName ?? user.email,
            settings: settings,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded successfully')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Attendance')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade100,
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Point camera at the office QR code for check-in or check-out.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
