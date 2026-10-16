class ApiInvoiceResponse {
  final int id;
  final int tenantId;
  final int unitId;
  final String service;
  final String ref;
  final double rent;
  final double amount;
  final String invoiceDate;
  final String status;
  final String createdAt;
  final String updatedAt;
  final ApiUnit unit;
  final List<ApiReceipt> receipts;

  ApiInvoiceResponse({
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
    required this.unit,
    required this.receipts,
  });

  factory ApiInvoiceResponse.fromJson(Map<String, dynamic> json) {
    return ApiInvoiceResponse(
      id: safeParseInt(json['id']),
      tenantId: safeParseInt(json['tenant_id']),
      unitId: safeParseInt(json['unit_id']),
      service: json['service'] ?? '',
      ref: json['ref'] ?? '',
      rent: safeParseDouble(json['rent']),
      amount: safeParseDouble(json['amount']),
      invoiceDate: json['invoice_date'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      unit: ApiUnit.fromJson(json['unit'] ?? {}),
      receipts: (json['receipts'] as List? ?? [])
          .map((r) => ApiReceipt.fromJson(r))
          .toList(),
    );
  }

  // Computed properties for UI
  double get amountAsDouble => amount;
  double get totalPaid => receipts.fold(0.0, (sum, r) => sum + r.amount);
  double get balance => amountAsDouble - totalPaid;

  // Helpers
  static int safeParseInt(dynamic input) {
    if (input == null) return 0;
    if (input is int) return input;
    if (input is String) return int.tryParse(input) ?? 0;
    return 0;
  }

  static double safeParseDouble(dynamic input) {
    if (input == null) return 0.0;
    if (input is num) return input.toDouble();
    if (input is String) {
      final cleaned = input.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }
}

class ApiUnit {
  final int id;
  final String unitNumber;
  final int bedrooms;
  final double rent;
  final String status;
  final ApiTenant tenant;
  final ApiProperty property; // 👈 ADD THIS

  ApiUnit({
    required this.id,
    required this.unitNumber,
    required this.bedrooms,
    required this.rent,
    required this.status,
    required this.tenant,
    required this.property,
  });

  factory ApiUnit.fromJson(Map<String, dynamic> json) {
    return ApiUnit(
      id: ApiInvoiceResponse.safeParseInt(json['id']),
      unitNumber: json['unitNumber'] ?? json['unit_number'] ?? '',
      bedrooms: ApiInvoiceResponse.safeParseInt(json['bedrooms']),
      rent: ApiInvoiceResponse.safeParseDouble(json['rent']),
      status: json['status'] ?? '',
      tenant: ApiTenant.fromJson(json['tenant'] ?? {}),

      // 👇 IMPORTANT: property comes from unit.property
      property: ApiProperty.fromJson(json['property'] ?? {}),
    );
  }
}

class ApiTenant {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String idNumber;

  ApiTenant({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.idNumber,
  });

  factory ApiTenant.fromJson(Map<String, dynamic> json) {
    return ApiTenant(
      id: ApiInvoiceResponse.safeParseInt(json['id']),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      idNumber: json['id_number'] ?? '',
    );
  }
}

class ApiReceipt {
  final int id;
  final int invoiceId;
  final String ref;
  final double amount;
  final String paymentDate;
  final String createdAt;

  ApiReceipt({
    required this.id,
    required this.invoiceId,
    required this.ref,
    required this.amount,
    required this.paymentDate,
    required this.createdAt,
  });

  factory ApiReceipt.fromJson(Map<String, dynamic> json) {
    return ApiReceipt(
      id: ApiInvoiceResponse.safeParseInt(json['id']),
      invoiceId: ApiInvoiceResponse.safeParseInt(json['invoice_id']),
      ref: json['ref'] ?? '',
      amount: ApiInvoiceResponse.safeParseDouble(json['amount']),
      paymentDate: json['payment_date'] ?? json['created_at'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }


}
class CreateReceiptRequest {
  final int invoiceId;
  final String ref;
  final double amount;
  final String paymentDate;
  final String? notes;

  CreateReceiptRequest({
    required this.invoiceId,
    required this.ref,
    required this.amount,
    required this.paymentDate,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'ref': ref,
      'amount': amount,
      'payment_date': paymentDate,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}

class CreateReceiptResponse {
  final String message;
  final ApiReceipt receipt;
  final double totalPaid;
  final double balance;

  CreateReceiptResponse({
    required this.message,
    required this.receipt,
    required this.totalPaid,
    required this.balance,
  });

  factory CreateReceiptResponse.fromJson(Map<String, dynamic> json) {
    return CreateReceiptResponse(
      message: json['message'] ?? 'Receipt created successfully',
      receipt: ApiReceipt.fromJson(json['receipt'] ?? {}),
      totalPaid: ApiInvoiceResponse.safeParseDouble(json['total_paid']),
      balance: ApiInvoiceResponse.safeParseDouble(json['balance']),
    );
  }

}
class ApiProperty {
  final int id;
  final String name;

  ApiProperty({
    required this.id,
    required this.name,
  });

  factory ApiProperty.fromJson(Map<String, dynamic> json) {
    return ApiProperty(
      id: ApiInvoiceResponse.safeParseInt(json['id']),
      name: json['name'] ?? '',
    );
  }
}