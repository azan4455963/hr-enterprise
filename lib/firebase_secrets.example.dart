/// Copy this file to `firebase_secrets.dart` and fill values from:
/// Firebase Console → Project settings → Your apps → Web (</>) app
///
/// Do NOT commit `firebase_secrets.dart` (it is in .gitignore).

class FirebaseSecrets {
  static const String projectId = 'your-project-id';
  static const String apiKey = 'AIzaSy...';
  static const String appId = '1:123456789:web:abcdef';
  static const String messagingSenderId = '123456789';
  static const String storageBucket = 'your-project-id.appspot.com';
  static const String authDomain = 'your-project-id.firebaseapp.com';

  /// Authentication → Google → Web client ID (not the Android client).
  static const String googleWebClientId =
      '123456789012-xxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com';
}
