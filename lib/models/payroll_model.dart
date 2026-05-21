import 'package:equatable/equatable.dart';

enum PaymentStatus { pending, paid, partial, cancelled }

class PayrollModel extends Equatable {
  const PayrollModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.year,
    required this.baseSalary,
    this.overtime = 0,
    this.deductions = 0,
    this.bonuses = 0,
    this.netSalary,
    this.status = PaymentStatus.pending,
    this.paidAt,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final int month;
  final int year;
  final double baseSalary;
  final double overtime;
  final double deductions;
  final double bonuses;
  final double? netSalary;
  final PaymentStatus status;
  final DateTime? paidAt;
  final String? notes;
  final DateTime? createdAt;

  double get calculatedNet =>
      netSalary ?? (baseSalary + overtime + bonuses - deductions);

  factory PayrollModel.fromMap(String id, Map<String, dynamic> map) {
    return PayrollModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      month: map['month'] as int? ?? 1,
      year: map['year'] as int? ?? DateTime.now().year,
      baseSalary: (map['baseSalary'] as num?)?.toDouble() ?? 0,
      overtime: (map['overtime'] as num?)?.toDouble() ?? 0,
      deductions: (map['deductions'] as num?)?.toDouble() ?? 0,
      bonuses: (map['bonuses'] as num?)?.toDouble() ?? 0,
      netSalary: (map['netSalary'] as num?)?.toDouble(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      paidAt: _parseDate(map['paidAt']),
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'month': month,
        'year': year,
        'baseSalary': baseSalary,
        'overtime': overtime,
        'deductions': deductions,
        'bonuses': bonuses,
        'netSalary': calculatedNet,
        'status': status.name,
        'paidAt': paidAt,
        'notes': notes,
        'createdAt': createdAt ?? DateTime.now(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, employeeId, month, year];
}
