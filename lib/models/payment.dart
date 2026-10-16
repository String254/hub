class RecentPayment {
  final String tenantName;
  final String unitNumber;
  final double amount;
  final double balance;
  final String status;
  final String paymentDate;


  RecentPayment({
    required this.tenantName,
    required this.unitNumber,
    required this.amount,
    required this.balance,
    required this.status,
    required this.paymentDate,
  });

  factory RecentPayment.fromJson(Map<String, dynamic> json) {
    return RecentPayment(
      tenantName: json['tenant_name'] ?? '',
      unitNumber: json['unit_number'] ?? '',
      amount: _toDouble(json['amount_paid']),
      balance: _toDouble(json['balance']),
      status: json['status'] ?? '',
      paymentDate: json['payment_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenant_name': tenantName,
      'unit_number': unitNumber,
      'amount_paid': amount,
      'balance': balance,
      'payment_date': paymentDate,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
  }
}
