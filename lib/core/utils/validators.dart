class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length < 10) return 'Enter a valid phone number';
    return null;
  }

  static String? cnic(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return 'CNIC must be 13 digits';
    return null;
  }

  static String? positiveNumber(String? value, [String field = 'Amount']) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value);
    if (n == null || n < 0) return '$field must be a valid positive number';
    return null;
  }
}
