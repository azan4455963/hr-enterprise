import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_exception.dart';
import '../firebase_secrets.dart';
import '../core/constants/permissions.dart';
import '../models/user_model.dart';
import 'audit_service.dart';
import 'user_backend_service.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    UserBackendService? userBackend,
    AuditService? audit,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userBackend = userBackend ?? UserBackendService(),
        _googleSignInOverride = googleSignIn,
        _audit = audit ?? AuditService();

  final FirebaseAuth _auth;
  final UserBackendService _userBackend;
  final GoogleSignIn? _googleSignInOverride;
  final AuditService _audit;

  // Built lazily on first use — constructing GoogleSignIn on web requires a
  // client ID, so we defer it until the user actually signs in with Google.
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInInstance ??= (_googleSignInOverride ?? _createGoogleSignIn());

  static GoogleSignIn _createGoogleSignIn() {
    if (kIsWeb || !FirebaseSecrets.isGoogleSignInConfigured) {
      return GoogleSignIn(scopes: ['email']);
    }
    return GoogleSignIn(
      scopes: ['email'],
      serverClientId: FirebaseSecrets.googleWebClientId,
    );
  }

  static const _rememberKey = 'remember_me';
  static const _emailKey = 'saved_email';

  static const _googleSetupMessage =
      'Google Sign-In needs your Web Client ID in lib/firebase_secrets.dart '
      '(googleWebClientId). Get it from Firebase Console → Authentication → '
      'Google → Web client ID. On Android also add SHA-1 in Firebase and place '
      'google-services.json in android/app/.';

  User? get firebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _userBackend.getUserByUid(user.uid);
  }

  Stream<UserModel?> watchCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _userBackend.watchUserByUid(user.uid);
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final profile = await _userBackend.ensureUserProfile(cred.user!);
    await _saveRememberMe(rememberMe, email);
    await _safeAuditLog(
      userId: cred.user!.uid,
      action: 'login',
      module: 'auth',
      details: {'method': 'email'},
    );
    return profile;
  }

  Future<UserModel> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    }
    if (!FirebaseSecrets.isGoogleSignInConfigured) {
      throw AppException(_googleSetupMessage);
    }
    return _signInWithGoogleNative();
  }

  Future<UserModel> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider()..addScope('email');
    final cred = await _auth.signInWithPopup(provider);
    final user = cred.user;
    if (user == null) {
      throw AppException('Google sign-in did not return a user.');
    }
    final profile = await _userBackend.ensureUserProfile(user);
    await _safeAuditLog(
      userId: user.uid,
      action: 'login',
      module: 'auth',
      details: {'method': 'google'},
    );
    return profile;
  }

  Future<UserModel> _signInWithGoogleNative() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AppException('Google sign-in cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null && accessToken == null) {
      throw AppException(
        'Google did not return auth tokens. Check googleWebClientId and '
        'Firebase Android setup (SHA-1 + google-services.json).',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final profile = await _userBackend.ensureUserProfile(cred.user!);
    await _safeAuditLog(
      userId: cred.user!.uid,
      action: 'login',
      module: 'auth',
      details: {'method': 'google'},
    );
    return profile;
  }

  /// Registers Auth user + Firestore `users/{uid}` (employee role, employeeId: null).
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String role = RolePermissions.employee,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(displayName);
    return _userBackend.createUserOnSignup(
      uid: cred.user!.uid,
      email: cred.user!.email ?? email,
      displayName: displayName,
      role: role,
    );
  }

  /// Creates super admin document for existing Auth uid (manual bootstrap).
  Future<UserModel> bootstrapSuperAdmin({
    required String uid,
    required String email,
    String? displayName,
  }) =>
      _userBackend.createSuperAdmin(
        uid: uid,
        email: email,
        displayName: displayName,
      );

  /// Promotes current signed-in user to super admin.
  Future<UserModel> bootstrapCurrentUserAsSuperAdmin() =>
      _userBackend.createSuperAdminForCurrentUser();

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google may not be signed in (email login).
    }
    await _auth.signOut();
    if (uid != null) {
      await _safeAuditLog(userId: uid, action: 'logout', module: 'auth');
    }
  }

  Future<void> _safeAuditLog({
    required String userId,
    required String action,
    required String module,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _audit.log(
        userId: userId,
        action: action,
        module: module,
        details: details,
      );
    } catch (_) {
      // Login must succeed even if audit write fails (e.g. rules/network).
    }
  }

  Future<void> _saveRememberMe(bool remember, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
    if (remember) {
      await prefs.setString(_emailKey, email);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  Future<({bool remember, String? email})> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      remember: prefs.getBool(_rememberKey) ?? false,
      email: prefs.getString(_emailKey),
    );
  }
}
