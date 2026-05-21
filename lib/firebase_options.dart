import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'firebase_secrets.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: FirebaseSecrets.apiKey,
        appId: FirebaseSecrets.appId,
        messagingSenderId: FirebaseSecrets.messagingSenderId,
        projectId: FirebaseSecrets.projectId,
        authDomain: FirebaseSecrets.authDomain,
        storageBucket: FirebaseSecrets.storageBucket,
      );

  static FirebaseOptions get android => web;

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: FirebaseSecrets.apiKey,
        appId: FirebaseSecrets.appId,
        messagingSenderId: FirebaseSecrets.messagingSenderId,
        projectId: FirebaseSecrets.projectId,
        storageBucket: FirebaseSecrets.storageBucket,
        iosBundleId: 'com.hrenterprise.hrEnterprise',
      );

  static FirebaseOptions get macos => ios;

  static FirebaseOptions get windows => web;
}
