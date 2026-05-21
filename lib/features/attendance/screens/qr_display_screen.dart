import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class QrDisplayScreen extends ConsumerWidget {
  const QrDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      permission: 'attendance_edit',
      fallback: const Scaffold(
        body: Center(child: Text('Only admins can display attendance QR codes')),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Attendance QR Codes')),
        body: ref.watch(activeQrSessionProvider).when(
              data: (session) {
                if (session == null) {
                  return _GenerateQrView();
                }
                final qrService = ref.read(attendanceQrServiceProvider);
                final checkIn = qrService.buildCheckInQr(session);
                final checkOut = qrService.buildCheckOutQr(session);
                final remaining =
                    session.expiresAt.difference(DateTime.now());

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Session expires in ${remaining.inMinutes} min',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      _QrCard(title: 'Check In', data: checkIn),
                      const SizedBox(height: 24),
                      _QrCard(title: 'Check Out', data: checkOut),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final user =
                              ref.read(currentUserProvider).valueOrNull;
                          if (user != null) {
                            await ref
                                .read(attendanceQrServiceProvider)
                                .createSession(createdBy: user.id);
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerate QR Session'),
                      ),
                    ],
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
      ),
    );
  }
}

class _GenerateQrView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          final user = ref.read(currentUserProvider).valueOrNull;
          if (user != null) {
            await ref
                .read(attendanceQrServiceProvider)
                .createSession(createdBy: user.id);
          }
        },
        icon: const Icon(Icons.qr_code),
        label: const Text('Generate QR Session'),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.title, required this.data});

  final String title;
  final String data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: 220,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
