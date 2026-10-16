class RevenueMonth {
  final String month;
  final int actual;
  final int projected;

  RevenueMonth({
    required this.month,
    required this.actual,
    required this.projected,
  });

  factory RevenueMonth.fromJson(Map<String, dynamic> json) {
    return RevenueMonth(
      month: json['month'],
      actual: json['actual_revenue'],
      projected: json['projected_revenue'],
    );
  }
}
