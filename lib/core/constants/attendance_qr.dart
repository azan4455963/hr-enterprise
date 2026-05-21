/// QR payload format: HR|{companyId}|{sessionToken}|{action}
/// action: IN or OUT
class AttendanceQrPayload {
  const AttendanceQrPayload({
    required this.companyId,
    required this.sessionToken,
    required this.action,
  });

  final String companyId;
  final String sessionToken;
  final String action;

  static const prefix = 'HR';

  String encode() => '$prefix|$companyId|$sessionToken|$action';

  static AttendanceQrPayload? decode(String raw) {
    final parts = raw.trim().split('|');
    if (parts.length != 4 || parts[0] != prefix) return null;
    if (parts[3] != 'IN' && parts[3] != 'OUT') return null;
    return AttendanceQrPayload(
      companyId: parts[1],
      sessionToken: parts[2],
      action: parts[3],
    );
  }
}
