import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'firebase_options.dart';
import 'services/messaging_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final messaging = MessagingService();
  await messaging.initialize();
  runApp(
    ProviderScope(
      overrides: [
        messagingServiceOverride.overrideWithValue(messaging),
      ],
      child: const HrEnterpriseApp(),
    ),
  );
}
