class PropertyResponse {
  final List<PropertyDialog> properties;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final List<UnitDialog> units;

  PropertyResponse({
    required this.properties,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.units,
  });

  factory PropertyResponse.fromJson(Map<String, dynamic> json) {
    //print("📥 Starting PropertyResponse parsing...");

    // Log overall stats from server
    final serverTotal = json['totalUnits'];
    final serverOccupied = json['occupiedUnits'];
    final serverVacant = json['vacantUnits'];

    //print("🌐 Server reported: Total=$serverTotal, Occupied=$serverOccupied, Vacant=$serverVacant");

    final rawUnits = json['units'] as List;
    //print("📦 Raw units count: ${rawUnits.length}");

    final List<UnitDialog> unitsList = [];

    // Parse each unit individually with debug info
    for (int i = 0; i < rawUnits.length; i++) {
      final unitJson = rawUnits[i];

      try {
        final unit = UnitDialog.fromJson(unitJson);

        unitsList.add(unit);
      } catch (e, stackTrace) {
        //print("❌ Failed to parse unit at index $i: $unitJson\nError: $e\nStack: $stackTrace");
      }
    }

    // Manual recount after parsing
    final calculatedOccupied = unitsList
        .where((u) => u.isOccupied)
        .length;
    final calculatedVacant = unitsList
        .where((u) => u.isVacant)
        .length;

    // Use server values if available, otherwise fall back to calculated
    final finalTotal = serverTotal ?? unitsList.length;
    final finalOccupied = serverOccupied ?? calculatedOccupied;
    final finalVacant = serverVacant ?? calculatedVacant;

    return PropertyResponse(
      properties: (json['properties'] as List)
          .map((propertyJson) => PropertyDialog.fromJson(propertyJson))
          .toList(),
      totalUnits: finalTotal,
      occupiedUnits: finalOccupied,
      vacantUnits: finalVacant,
      units: unitsList,
    );
  }

}

// lib/models/property.dart
class PropertyDialog {
  final int id;
  final String name;
  final String type;
  final String location;
  final int totalUnits;
  final int userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<UnitDialog> units;

  const PropertyDialog({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.totalUnits,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.units,
  });

  factory PropertyDialog.fromJson(Map<String, dynamic> json) {
    return PropertyDialog(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      location: json['location'],
      totalUnits: json['total_units'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      units: (json['units'] as List)
          .map((unitJson) => UnitDialog.fromJson(unitJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'location': location,
      'total_units': totalUnits,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'units': units.map((u) => u.toJson()).toList(),
    };
  }
}

class UnitDialog {
  final int id;
  final int propertyId;
  final String unitNumber;
  final String status;
  final double rentAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TenantDialog? tenant;
  final InvoiceDialog? latestInvoice;

  const UnitDialog({
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

  factory UnitDialog.fromJson(Map<String, dynamic> json) {
    return UnitDialog(
      id: json['id'],
      propertyId: json['property_id'],
      unitNumber: json['unit_number'],
      status: json['status'],
      rentAmount: double.parse(json['rent_amount'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      tenant: json['tenant'] != null
          ? TenantDialog.fromJson(json['tenant'])
          : null,
      latestInvoice: json['latest_invoice'] != null
          ? InvoiceDialog.fromJson(json['latest_invoice'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'unit_number': unitNumber,
      'status': status,
      'rent_amount': rentAmount.toString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tenant': tenant?.toJson(),
      'latest_invoice': latestInvoice?.toJson(),
    };
  }

  // Helper methods
  bool get isOccupied => status.trim().toLowerCase() == 'occupied';
  bool get isVacant => status.trim().toLowerCase() == 'vacant';
  bool get hasInvoice => latestInvoice != null;
  bool get isInvoicePaid => latestInvoice?.status == 'paid';
  bool get isInvoiceUnpaid => latestInvoice?.status == 'unpaid';
  bool get isInvoicePartial => latestInvoice?.status == 'partial';
}

// lib/models/tenant.dart
class TenantDialog {
  final int id;
  final int unitId;
  final String name;
  final String email;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TenantDialog({
    required this.id,
    required this.unitId,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TenantDialog.fromJson(Map<String, dynamic> json) {
    return TenantDialog(
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

// lib/models/invoice.dart
class InvoiceDialog {
  final int id;
  final int tenantId;
  final int unitId;
  final String service;
  final String ref;
  final String rent;
  final String amount;
  final String invoiceDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvoiceDialog({
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

  factory InvoiceDialog.fromJson(Map<String, dynamic> json) {
    return InvoiceDialog(
      id: json['id'],
      tenantId: json['tenant_id'],
      unitId: json['unit_id'],
      service: json['service'],
      ref: json['ref'],
      rent: json['rent'],
      amount: json['amount'],
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

  // Helper methods
  bool get isPaid => status == 'paid';
  bool get isUnpaid => status == 'unpaid';
  bool get isPartial => status == 'partial';
  double get serviceAmount => double.parse(service);
  double get rentAmount => double.parse(rent);
  double get totalAmount => double.parse(amount);
  double get paidAmount => isPaid ? totalAmount : 0.0;
}
