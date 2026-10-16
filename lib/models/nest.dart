class Nest {
  final int id;
  final String name;
  final String type;
  final String location;
  final String? paymentMethod;
  final String? paybillNumber;
  final String? accountNumber;
  final int totalUnits;

  Nest({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    this.paymentMethod,
    this.paybillNumber,
    this.accountNumber,
    required this.totalUnits,
  });

  factory Nest.fromJson(Map<String, dynamic> json) {
    return Nest(
      id: json['id'],
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      location: json['location'] ?? '',

      paymentMethod: json['payment_method']?.toString(),

      paybillNumber: json['paybill_number']?.toString(),

      accountNumber: json['account_number']?.toString(),

      totalUnits: int.tryParse(
        json['total_units']?.toString() ?? '0',
      ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'location': location,
      'payment_method': paymentMethod,
      'paybill_number': paybillNumber,
      'account_number': accountNumber,
      'total_units': totalUnits,
    };
  }
}