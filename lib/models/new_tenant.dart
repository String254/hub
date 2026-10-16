class NewTenant {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final int? unitId;
  final String? unitNumber;

  NewTenant({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.unitId,
    this.unitNumber,
  });

  factory NewTenant.fromJson(Map<String, dynamic> json) {
    return NewTenant(
      id: json['id'] is int
          ? json['id']
          : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      unitId: json['unit_id'],
      unitNumber: json['unit_number']?.toString(),
    );
  }
}