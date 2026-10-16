class MaintenanceNotification {
  final int id;
  final String name;
  final String houseNo;
  final String subject;
  final String description;
  final String status;
  final String createdAt;
  final MaintenanceUnit? unit;
  final MaintenanceProperty? property;
  final MaintenanceTenant? tenant;

  MaintenanceNotification({
    required this.id,
    required this.name,
    required this.houseNo,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.unit,
    this.property,
    this.tenant,
  });

  factory MaintenanceNotification.fromJson(
      Map<String, dynamic> json,
      ) {
    return MaintenanceNotification(
      id: int.tryParse(
        json['id']?.toString() ?? '',
      ) ??
          0,
      name: json['name']?.toString() ?? '',
      houseNo: json['house_no']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      unit: json['unit'] is Map<String, dynamic>
          ? MaintenanceUnit.fromJson(
        json['unit'] as Map<String, dynamic>,
      )
          : null,
      property: json['property'] is Map<String, dynamic>
          ? MaintenanceProperty.fromJson(
        json['property'] as Map<String, dynamic>,
      )
          : null,
      tenant: json['tenant'] is Map<String, dynamic>
          ? MaintenanceTenant.fromJson(
        json['tenant'] as Map<String, dynamic>,
      )
          : null,
    );
  }
}

class MaintenanceUnit {
  final int id;
  final String unitNumber;
  final num? rentAmount;
  final String status;

  MaintenanceUnit({
    required this.id,
    required this.unitNumber,
    this.rentAmount,
    required this.status,
  });

  factory MaintenanceUnit.fromJson(
      Map<String, dynamic> json,
      ) {
    return MaintenanceUnit(
      id: int.tryParse(
        json['id']?.toString() ?? '',
      ) ??
          0,
      unitNumber: json['unit_number']?.toString() ?? '',
      rentAmount: json['rent_amount'] is num
          ? json['rent_amount'] as num
          : num.tryParse(
        json['rent_amount']?.toString() ?? '',
      ),
      status: json['status']?.toString() ?? '',
    );
  }
}

class MaintenanceProperty {
  final int id;
  final String name;
  final String type;
  final String location;

  MaintenanceProperty({
    required this.id,
    required this.name,
    this.type = '',
    this.location = '',
  });

  factory MaintenanceProperty.fromJson(
      Map<String, dynamic> json,
      ) {
    return MaintenanceProperty(
      id: int.tryParse(
        json['id']?.toString() ?? '',
      ) ??
          0,
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }
}

class MaintenanceTenant {
  final int id;
  final String name;
  final String email;
  final String phone;

  MaintenanceTenant({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
  });

  factory MaintenanceTenant.fromJson(
      Map<String, dynamic> json,
      ) {
    return MaintenanceTenant(
      id: int.tryParse(
        json['id']?.toString() ?? '',
      ) ??
          0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}