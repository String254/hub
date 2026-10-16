class UnitsDetails {
  final int id;
  final int propertyId;
  final String unitNumber;
  final String status;
  final double rentAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TenantDetails? tenant;
  final InvoiceDetails? latestInvoice;

  UnitsDetails({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.status,
    required this.rentAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.tenant,
    required this.latestInvoice,
  });

  factory UnitsDetails.fromJson(Map<String, dynamic> json) {
    return UnitsDetails(
      id: json['id'],
      propertyId: json['property_id'],
      unitNumber: json['unit_number'],
      status: json['status'],
      rentAmount: double.parse(json['rent_amount'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      tenant: json['tenant'] != null
          ? TenantDetails.fromJson(json['tenant'])
          : null,
      latestInvoice: json['latest_invoice'] != null
          ? InvoiceDetails.fromJson(json['latest_invoice'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'unit_number': unitNumber,
      'status': status,
      'rent_amount': rentAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tenant': tenant?.toJson(),
      'latest_invoice': latestInvoice?.toJson(),
    };
  }
}

class TenantDetails {
  final int id;
  final int unitId;
  final String name;
  final String email;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  TenantDetails({
    required this.id,
    required this.unitId,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TenantDetails.fromJson(Map<String, dynamic> json) {
    return TenantDetails(
      id: json['id'],
      unitId: json['unit_id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unit_id': unitId,
      'name': name,
      'email': email,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class InvoiceDetails {
  final int id;
  final int tenantId;
  final int unitId;
  final double service;
  final String ref;
  final double rent;
  final double amount;
  final String invoiceDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvoiceDetails({
    required this.id,
    required this.tenantId,
    required this.unitId,
    required this.service,
    required this.ref,
    required this.rent,
    required this.amount,
    required this.invoiceDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvoiceDetails.fromJson(Map<String, dynamic> json) {
    return InvoiceDetails(
      id: json['id'],
      tenantId: json['tenant_id'],
      unitId: json['unit_id'],
      service: double.parse(json['service'].toString()),
      ref: json['ref'],
      rent: double.parse(json['rent'].toString()),
      amount: double.parse(json['amount'].toString()),
      invoiceDate: json['invoice_date'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'unit_id': unitId,
      'service': service,
      'ref': ref,
      'rent': rent,
      'amount': amount,
      'invoice_date': invoiceDate,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}


