import 'package:firebase_auth/firebase_auth.dart';

class AppException implements Exception {
  AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;

  static AppException from(dynamic error) {
    if (error is AppException) return error;
    if (error is FirebaseAuthException) {
      return AppException(_authMessage(error), code: error.code);
    }
    final text = error.toString();
    if (text.contains('permission-denied')) {
      return AppException(
        'You do not have permission for this action.',
        code: 'permission-denied',
      );
    }
    if (text.contains('network')) {
      return AppException('Network error. Check your connection.', code: 'network');
    }
    if (text.contains('user-not-found') ||
        text.contains('wrong-password') ||
        text.contains('invalid-credential')) {
      return AppException('Invalid email or password.', code: 'auth');
    }
    if (text.contains('email-already-in-use')) {
      return AppException('This email is already registered.', code: 'auth');
    }
    if (text.contains('invalid-email')) {
      return AppException('Enter a valid email address.', code: 'auth');
    }
    if (text.contains('too-many-requests')) {
      return AppException('Too many attempts. Try again later.', code: 'auth');
    }
    if (text.contains('popup-closed-by-user') ||
        text.contains('cancelled-popup-request')) {
      return AppException('Google sign-in cancelled.');
    }
    if (text.contains('account-exists-with-different-credential')) {
      return AppException(
        'This email is already registered with another sign-in method.',
        code: 'auth',
      );
    }
    if (text.contains('sign_in_failed') ||
        text.contains('ApiException: 10') ||
        text.contains('DEVELOPER_ERROR')) {
      return AppException(
        'Google Sign-In setup is incomplete. Add googleWebClientId in '
        'firebase_secrets.dart, SHA-1 in Firebase (Android), and '
        'google-services.json in android/app/.',
        code: 'google-auth',
      );
    }
    if (text.contains('googleWebClientId') ||
        text.contains('Web Client ID')) {
      return AppException(
        'Add googleWebClientId in lib/firebase_secrets.dart (Firebase → '
        'Authentication → Google → Web client ID).',
        code: 'google-auth',
      );
    }
    return AppException('Something went wrong. Please try again.');
  }

  static String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return error.message ?? 'Sign in failed. Please try again.';
    }
  }
}
