import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/attendance_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/user_repository.dart';
import '../services/attendance_qr_service.dart';
import '../services/attendance_service.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/company_settings_service.dart';
import '../services/department_service.dart';
import '../services/employee_document_service.dart';
import '../services/employee_record_service.dart';
import '../services/employee_service.dart';
import '../services/employee_user_link_service.dart';
import '../services/user_backend_service.dart';
import '../services/export_service.dart';
import '../services/leave_service.dart';
import '../bootstrap.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import '../services/payroll_service.dart';
import '../services/rbac_service.dart';
import '../services/storage_service.dart';
import '../services/user_admin_service.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());
final employeeRepositoryProvider =
    Provider<EmployeeRepository>((ref) => EmployeeRepository());
final attendanceRepositoryProvider =
    Provider<AttendanceRepository>((ref) => AttendanceRepository());

final userBackendServiceProvider = Provider<UserBackendService>((ref) {
  return UserBackendService(userRepository: ref.watch(userRepositoryProvider));
});

final employeeUserLinkServiceProvider =
    Provider<EmployeeUserLinkService>((ref) {
  return EmployeeUserLinkService(
    userRepository: ref.watch(userRepositoryProvider),
    employeeRepository: ref.watch(employeeRepositoryProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(userBackend: ref.watch(userBackendServiceProvider));
});

final rbacServiceProvider = Provider<RbacService>((ref) => RbacService());
final auditServiceProvider = Provider<AuditService>((ref) => AuditService());

final employeeServiceProvider = Provider<EmployeeService>((ref) {
  return EmployeeService(
    employeeRepository: ref.watch(employeeRepositoryProvider),
    linkService: ref.watch(employeeUserLinkServiceProvider),
  );
});

final employeeRecordServiceProvider =
    Provider<EmployeeRecordService>((ref) => EmployeeRecordService());

final employeeDocumentServiceProvider =
    Provider<EmployeeDocumentService>((ref) => EmployeeDocumentService());

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService(
    attendanceRepository: ref.watch(attendanceRepositoryProvider),
    userBackend: ref.watch(userBackendServiceProvider),
  );
});

final canMarkAttendanceProvider = FutureProvider.family<bool, String>((ref, uid) {
  return ref.watch(userBackendServiceProvider).canMarkAttendance(uid);
});
final attendanceQrServiceProvider =
    Provider<AttendanceQrService>((ref) => AttendanceQrService());
final leaveServiceProvider = Provider<LeaveService>((ref) => LeaveService());
final payrollServiceProvider =
    Provider<PayrollService>((ref) => PayrollService());
final onboardingServiceProvider =
    Provider<OnboardingService>((ref) => OnboardingService());
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
final messagingServiceProvider = messagingServiceOverride;
final exportServiceProvider = Provider<ExportService>((ref) => ExportService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final companySettingsServiceProvider =
    Provider<CompanySettingsService>((ref) => CompanySettingsService());
final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());
final departmentServiceProvider = Provider<DepartmentService>((ref) {
  return DepartmentService(userRepository: ref.watch(userRepositoryProvider));
});
final userAdminServiceProvider = Provider<UserAdminService>((ref) {
  return UserAdminService(userRepository: ref.watch(userRepositoryProvider));
});
