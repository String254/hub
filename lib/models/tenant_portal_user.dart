class TenantPortalUser {
  final int id;
  final String name;
  final String email;
  final String phone;
  final DateTime? createdAt;

  final TenantPortalUnit unit;
  final TenantPortalProperty property;

  TenantPortalUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
    required this.unit,
    required this.property,
  });

  factory TenantPortalUser.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantPortalUser(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(
        json['created_at'].toString(),
      )
          : null,
      unit: TenantPortalUnit.fromJson(
        Map<String, dynamic>.from(
          json['unit'] ?? {},
        ),
      ),
      property: TenantPortalProperty.fromJson(
        Map<String, dynamic>.from(
          json['property'] ?? {},
        ),
      ),
    );
  }
}

class TenantPortalUnit {
  final int id;
  final String unitNumber;
  final double? rentAmount;
  final String? status;

  TenantPortalUnit({
    required this.id,
    required this.unitNumber,
    this.rentAmount,
    this.status,
  });

  factory TenantPortalUnit.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantPortalUnit(
      id: json['id'] ?? 0,
      unitNumber:
      json['unit_number']?.toString() ?? '',
      rentAmount: json['rent_amount'] != null
          ? double.tryParse(
        json['rent_amount'].toString(),
      )
          : null,
      status: json['status']?.toString(),
    );
  }
}

class TenantPortalProperty {
  final int id;
  final String name;
  final String location;

  TenantPortalProperty({
    required this.id,
    required this.name,
    required this.location,
  });

  factory TenantPortalProperty.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantPortalProperty(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }
}