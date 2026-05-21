class AppConstants {
  static const String appName = 'HR Enterprise';
  static const String companyId = 'default_company';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String employeesCollection = 'employees';
  static const String departmentsCollection = 'departments';
  static const String attendanceCollection = 'attendance';
  static const String leaveCollection = 'leave_requests';
  static const String payrollCollection = 'payroll';
  static const String onboardingCollection = 'onboarding_links';
  static const String onboardingSubmissionsCollection = 'onboarding_submissions';
  static const String notificationsCollection = 'notifications';
  static const String auditLogsCollection = 'audit_logs';
  static const String companySettingsCollection = 'company_settings';
  static const String rolesCollection = 'roles';
  static const String attendanceQrSessionsCollection = 'attendance_qr_sessions';
  static const String fcmTokensCollection = 'fcm_tokens';

  /// QR session validity in minutes
  static const int qrSessionValidityMinutes = 30;

  static const int onboardingLinkExpiryDays = 7;
  static const double borderRadius = 20;
  static const double borderRadiusSmall = 16;
}
