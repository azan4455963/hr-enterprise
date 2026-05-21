import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores credentials securely and unlocks app via device biometrics.
class BiometricService {
  BiometricService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;

  static const _enabledKey = 'biometric_enabled';
  static const _emailKey = 'biometric_email';
  static const _passwordKey = 'biometric_password';

  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> enable({
    required String email,
    required String password,
  }) async {
    final supported = await isDeviceSupported();
    if (!supported) throw Exception('Biometric authentication not available');

    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Enable biometric login for HR Enterprise',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (!authenticated) throw Exception('Biometric verification failed');

    await _secureStorage.write(key: _emailKey, value: email);
    await _secureStorage.write(key: _passwordKey, value: password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
  }

  Future<void> disable() async {
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<({String email, String password})?> unlockCredentials() async {
    if (!await isEnabled()) return null;
    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Sign in to HR Enterprise',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (!authenticated) return null;
    final email = await _secureStorage.read(key: _emailKey);
    final password = await _secureStorage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }
}
