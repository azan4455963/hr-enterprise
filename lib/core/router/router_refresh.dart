import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import 'route_permissions.dart';

/// Notifies [GoRouter] when auth/profile changes without recreating the router.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) => notifyListeners());
    _ref.listen(currentUserProvider, (previous, next) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(GoRouterState state) {
    final path = state.matchedLocation;

    if (path.startsWith('/onboard/')) return null;

    final isAuthRoute = path.startsWith('/login') ||
        path.startsWith('/register') ||
        path.startsWith('/forgot');

    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) {
      // Allow /login briefly while Firebase auth stream catches up after sign-out.
      final authAsync = _ref.read(authStateProvider);
      if (authAsync.isLoading) return null;
      return '/dashboard';
    }

    if (isLoggedIn) {
      final authAsync = _ref.read(authStateProvider);
      final userProfile = _ref.read(currentUserProvider);

      if (authAsync.isLoading || userProfile.isLoading) return null;

      final user = userProfile.valueOrNull;
      if (user != null) {
        final requiredPerm = RoutePermissions.permissionForPath(path);
        if (requiredPerm != null && !user.hasPermission(requiredPerm)) {
          return '/unauthorized';
        }
        if (path == '/employees/new' &&
            !user.hasPermission('employees_create')) {
          return '/unauthorized';
        }
      }
    }

    return null;
  }
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
