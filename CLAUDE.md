# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run (pick a target)
flutter run -d windows
flutter run -d chrome
flutter run -d android

# Analyze (lint)
flutter analyze

# Run tests
flutter test
flutter test test/path/to/specific_test.dart

# Build
flutter build apk
flutter build web
flutter build windows

# Firebase deployment
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## Architecture Overview

This is a Flutter + Firebase HR platform using **Riverpod** for state management and **GoRouter** for navigation.

### Entry points

- [`lib/main.dart`](lib/main.dart) — bootstraps Firebase, initializes `MessagingService`, and wraps the app in `ProviderScope` (injecting the messaging override)
- [`lib/app.dart`](lib/app.dart) — `HrEnterpriseApp`: wires router, theme, and `ResponsiveBreakpoints`
- [`lib/bootstrap.dart`](lib/bootstrap.dart) — declares provider overrides (the `messagingServiceOverride` extension point for DI/tests)

### Provider layers

| Layer | Files | Purpose |
|-------|-------|---------|
| Service providers | [`lib/providers/service_providers.dart`](lib/providers/service_providers.dart) | Constructs all services/repositories as Riverpod `Provider<T>` |
| Auth providers | [`lib/providers/auth_provider.dart`](lib/providers/auth_provider.dart) | `authStateProvider` (Firebase stream), `currentUserProvider` (Firestore `UserModel`) |
| Data providers | [`lib/providers/data_providers.dart`](lib/providers/data_providers.dart) | All `StreamProvider` / `FutureProvider` for Firestore collections; dashboard computations live here |

### Routing & access control

[`lib/core/router/app_router.dart`](lib/core/router/app_router.dart) defines a `GoRouter` with a `ShellRoute` (renders the `AppShell` nav frame) wrapping all authenticated routes. Auth routes (`/login`, `/register`, `/forgot-password`) and `/onboard/:token` are outside the shell.

[`RouterRefreshNotifier`](lib/core/router/router_refresh.dart) listens to `authStateProvider` + `currentUserProvider` and drives all redirects:
- Unauthenticated → `/login`
- Authenticated on auth route → `/dashboard`
- Missing permission → `/unauthorized`

Permission keys per route are declared in [`lib/core/router/route_permissions.dart`](lib/core/router/route_permissions.dart).

### RBAC

Roles live in Firestore `users/{uid}`. Active roles are only `super_admin` and `employee` (`RolePermissions.includeInactiveRoles = false` in [`lib/core/constants/permissions.dart`](lib/core/constants/permissions.dart)). `admin`, `hr_manager`, and `manager` are defined but inactive — flip that one constant to re-enable them app-wide.

Permission check flow: `UserModel.hasPermission(key)` → `RolePermissions.userHasPermission()` → resolves stored permissions or role defaults. A `super_admin` with `["*"]` bypasses all checks.

### Service / repository pattern

Repositories (`lib/repositories/`) own raw Firestore CRUD. Services (`lib/services/`) compose repositories and contain business logic. Features never call Firestore directly — they go through service providers.

### Key services

| Service | Responsibility |
|---------|---------------|
| `AuthService` | Firebase Auth + Firestore user profile write-back |
| `AttendanceService` | Manual check-in/out, today stats, QR validation |
| `AttendanceQrService` | Create/watch 30-min QR sessions |
| `RbacService` | `getModuleAccess(user)` map used by `AppShell` to filter nav items |
| `ExportService` | PDF (via `printing`) + Excel (via `excel`) export |
| `MessagingService` | FCM token save; `notifyRole()` for in-app fan-out |
| `AuditService` | Writes audit log entries; dashboard reads the last 25 |

### UI shell

[`AppShell`](lib/features/shell/app_shell.dart) renders a sidebar on desktop and bottom nav on mobile (via `responsive_framework`). Nav items are filtered by `RbacService.getModuleAccess()` and carry live badge counts from `pendingLeaveProvider`, `onboardingPendingCountProvider`, and `unreadNotificationsCountProvider`.

### Firebase setup (first run)

1. Run `flutterfire configure` to generate `lib/firebase_options.dart` (use `lib/firebase_secrets.example.dart` as reference).
2. Enable Authentication (Email + Google), Firestore, Storage, Cloud Messaging.
3. Deploy rules: `firebase deploy --only firestore:rules,firestore:indexes,storage`
4. Manually set `role: "super_admin", permissions: ["*"]` on the first user document in Firestore.
