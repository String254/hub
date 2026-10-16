class DashboardMetrics {
  final int totalUnits;
  final double rentDueThisMonth;
  final double rentPaidThisMonth;
  final int paidUnits;
  final int unpaidUnits;
  final double overdueRent;

  DashboardMetrics({
    required this.totalUnits,
    required this.rentDueThisMonth,
    required this.rentPaidThisMonth,
    required this.paidUnits,
    required this.unpaidUnits,
    required this.overdueRent,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalUnits: json['total_units'] as int,
      rentDueThisMonth: (json['rent_due_this_month'] as num).toDouble(),
      rentPaidThisMonth: (json['rent_paid_this_month'] as num).toDouble(),
      paidUnits: json['paid_units'] as int,
      unpaidUnits: json['unpaid_units'] as int,
      overdueRent: (json['overdue_rent'] as num).toDouble(),
    );
  }
}
