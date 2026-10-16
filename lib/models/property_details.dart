class PropertyDetails {
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final double occupancyRate;
  final int paidUnits;
  final int unpaidUnits;

  PropertyDetails({
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.occupancyRate,
    required this.paidUnits,
    required this.unpaidUnits,
  });

  factory PropertyDetails.fromJson(Map<String, dynamic> json) {
    return PropertyDetails(
      totalUnits: json['total_units'],
      occupiedUnits: json['occupied_units'],
      vacantUnits: json['vacant_units'],
      occupancyRate: (json['occupancy_rate'] as num).toDouble(),
      paidUnits: json['paid_units'],
      unpaidUnits: json['unpaid_units'],
    );
  }
}

class Payment {
  final String tenantName;
  final String houseNo;
  final double amountPaid;
  final double balance;
  final String date;

  Payment({
    required this.tenantName,
    required this.houseNo,
    required this.amountPaid,
    required this.balance,
    required this.date,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      tenantName: json['tenant_name'] ?? "",
      houseNo: json['unit_number'] ?? "",
      amountPaid: _parseDouble(json['amount_paid']),
      balance: _parseDouble(json['balance']),
      date: json['payment_date'] ?? "",
    );
  }

  // Helper: safely convert dynamic to double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
    return 0.0;
  }
}

class TenantInfo {
  final int tenantId;
  final String name;
  final String email;
  final String unitNumber;
  final String status;
  final int unitId;

  TenantInfo({
    required this.tenantId,
    required this.name,
    required this.email,
    required this.unitNumber,
    required this.status,
    required this.unitId,
  });

  factory TenantInfo.fromJson(Map<String, dynamic> json) {
    return TenantInfo(
      tenantId: json['tenant_id'] ?? '',
      name: (json['tenant_name'] ?? '').toString().trim(),
      email: (json['tenant_email'] ?? '').toString().trim(),
      unitNumber: json['unit_number'] ?? '',
      status: json['status'] ?? 'unpaid',
      unitId: json['unit_id'] ?? '',
    );
  }

}

class MonthlyRevenue {
  final String month;
  final double actualRevenue;
  final double projectedRevenue;
  final int occupiedUnits;

  MonthlyRevenue({
    required this.month,
    required this.actualRevenue,
    required this.projectedRevenue,
    required this.occupiedUnits,
  });

  factory MonthlyRevenue.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenue(
      month: json['month'],
      actualRevenue:
      double.tryParse(json['actual_revenue'].toString()) ?? 0,
      projectedRevenue:
      double.tryParse(json['projected_revenue'].toString()) ?? 0,
      occupiedUnits: json['occupied_units'] ?? 0,
    );
  }
}


