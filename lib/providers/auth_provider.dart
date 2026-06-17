import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'service_providers.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authServiceProvider).watchCurrentUserProfile();
    },
    loading: () => Stream.value(null),
    error: (error, stackTrace) => Stream.value(null),
  );
});

final rememberMeProvider = FutureProvider<({bool remember, String? email})>(
  (ref) => ref.watch(authServiceProvider).getRememberMe(),
);

final authLoadingProvider = StateProvider<bool>((ref) => false);

/// Set true on explicit sign-out so login does not auto biometric sign-in again.
final skipBiometricOnLoginProvider = StateProvider<bool>((ref) => false);

/// Tracks whether admin/super_admin is viewing in "employee mode"
/// When true, admin sees only what employees can see.
final employeeViewModeProvider = StateProvider<bool>((ref) => false);
