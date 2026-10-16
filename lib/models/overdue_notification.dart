class OverdueNotification {
  final int id;
  final String invoiceRef;
  final double amount;
  final double paid;
  final double balance;
  final String invoiceDate;
  final String status;
  final OverdueUnit? unit;
  final OverdueTenant? tenant;
  final OverdueProperty? property;

  OverdueNotification({
    required this.id,
    required this.invoiceRef,
    required this.amount,
    required this.paid,
    required this.balance,
    required this.invoiceDate,
    required this.status,
    this.unit,
    this.tenant,
    this.property,
  });

  factory OverdueNotification.fromJson(
      Map<String, dynamic> json) {
    return OverdueNotification(
      id: json['id'],
      invoiceRef: json['invoice_ref'] ?? '',
      amount: double.tryParse(
        json['amount']?.toString() ?? '0',
      ) ??
          0,
      paid: double.tryParse(
        json['paid']?.toString() ?? '0',
      ) ??
          0,
      balance: double.tryParse(
        json['balance']?.toString() ?? '0',
      ) ??
          0,
      invoiceDate: json['invoice_date'] ?? '',
      status: json['status'] ?? '',
      unit: json['unit'] != null
          ? OverdueUnit.fromJson(json['unit'])
          : null,
      tenant: json['tenant'] != null
          ? OverdueTenant.fromJson(json['tenant'])
          : null,
      property: json['property'] != null
          ? OverdueProperty.fromJson(json['property'])
          : null,
    );
  }
}

class OverdueUnit {
  final int id;
  final String unitNumber;

  OverdueUnit({
    required this.id,
    required this.unitNumber,
  });

  factory OverdueUnit.fromJson(Map<String, dynamic> json) {
    return OverdueUnit(
      id: json['id'],
      unitNumber: json['unit_number']?.toString() ?? '',
    );
  }
}

class OverdueTenant {
  final int id;
  final String name;
  final String email;
  final String? phone;

  OverdueTenant({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
  });

  factory OverdueTenant.fromJson(Map<String, dynamic> json) {
    return OverdueTenant(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
    );
  }
}

class OverdueProperty {
  final int id;
  final String name;

  OverdueProperty({
    required this.id,
    required this.name,
  });

  factory OverdueProperty.fromJson(Map<String, dynamic> json) {
    return OverdueProperty(
      id: json['id'],
      name: json['name'] ?? '',
    );
  }
}