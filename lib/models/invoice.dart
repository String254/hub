class Invoice {
  final int id;
  final double rent;
  final String ref;
  final double amount;
  final String status;
  final String invoiceDate;
  final String unitNumber;

  Invoice({
    required this.id,
    required this.rent,
    required this.ref,
    required this.amount,
    required this.status,
    required this.invoiceDate,
    required this.unitNumber,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      rent: double.parse(json['rent']),
      ref: json['ref'],
      amount: double.parse(json['amount']),
      status: json['status'],
      invoiceDate: json['invoice_date'],
      unitNumber: json['unit']['unit_number'],
    );
  }
}
