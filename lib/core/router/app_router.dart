import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/attendance/screens/qr_display_screen.dart';
import '../../features/attendance/screens/qr_scan_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/employees/screens/employee_detail_screen.dart';
import '../../features/employees/screens/employee_form_screen.dart';
import '../../features/employees/screens/employees_screen.dart';
import '../../features/leave/screens/leave_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/onboarding/screens/onboarding_admin_screen.dart';
import '../../features/onboarding/screens/onboarding_public_screen.dart';
import '../../features/payroll/screens/payroll_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/unauthorized_screen.dart';
import 'router_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) => refresh.redirect(state),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboard/:token',
        builder: (context, state) => OnboardingPublicScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const EmployeeFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => EmployeeDetailScreen(
                  employeeId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => EmployeeFormScreen(
                      employeeId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
            routes: [
              GoRoute(
                path: 'scan',
                builder: (context, state) => const QrScanScreen(),
              ),
              GoRoute(
                path: 'qr-display',
                builder: (context, state) => const QrDisplayScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/leave',
            builder: (context, state) => const LeaveScreen(),
          ),
          GoRoute(
            path: '/payroll',
            builder: (context, state) => const PayrollScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingAdminScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
