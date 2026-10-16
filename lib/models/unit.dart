class Unit {
  final int id;
  final int propertyId;
  final String unitNumber;
  final int rentAmount;
  final String status;
  final String createdAt;
  final String updatedAt;

  Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.rentAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'],
      propertyId: int.parse(json['property_id'].toString()),
      unitNumber: json['unit_number'],
      rentAmount: int.parse(json['rent_amount'].toString()),
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
