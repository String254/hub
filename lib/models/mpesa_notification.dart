class MpesaNotification {
  final int id;
  final String transactionId;
  final String transactionType;
  final String transactionTime;
  final double amount;
  final String businessShortCode;
  final String billRefNumber;
  final String accountNumber;
  final String unitNumber;
  final String? msisdn;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final MpesaNotificationUnit? unit;
  final MpesaNotificationTenant? tenant;
  final MpesaNotificationProperty? property;

  MpesaNotification({
    required this.id,
    required this.transactionId,
    required this.transactionType,
    required this.transactionTime,
    required this.amount,
    required this.businessShortCode,
    required this.billRefNumber,
    required this.accountNumber,
    required this.unitNumber,
    this.msisdn,
    this.firstName,
    this.middleName,
    this.lastName,
    this.unit,
    this.tenant,
    this.property,
  });

  factory MpesaNotification.fromJson(Map<String, dynamic> json) {
    return MpesaNotification(
      id: json['id'],
      transactionId: json['transaction_id'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      transactionTime: json['transaction_time'] ?? '',
      amount: double.tryParse(
        json['amount']?.toString() ?? '0',
      ) ??
          0,
      businessShortCode:
      json['business_short_code']?.toString() ?? '',
      billRefNumber: json['bill_ref_number'] ?? '',
      accountNumber: json['account_number'] ?? '',
      unitNumber: json['unit_number']?.toString() ?? '',
      msisdn: json['msisdn'],
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      unit: json['unit'] != null
          ? MpesaNotificationUnit.fromJson(json['unit'])
          : null,
      tenant: json['tenant'] != null
          ? MpesaNotificationTenant.fromJson(json['tenant'])
          : null,
      property: json['property'] != null
          ? MpesaNotificationProperty.fromJson(json['property'])
          : null,
    );
  }

  String get tenantName {
    if (tenant?.name != null && tenant!.name!.isNotEmpty) {
      return tenant!.name!;
    }

    return [
      firstName,
      middleName,
      lastName,
    ].where((e) => e != null && e!.isNotEmpty).join(' ');
  }
}

class MpesaNotificationUnit {
  final int id;
  final String unitNumber;

  MpesaNotificationUnit({
    required this.id,
    required this.unitNumber,
  });

  factory MpesaNotificationUnit.fromJson(Map<String, dynamic> json) {
    return MpesaNotificationUnit(
      id: json['id'],
      unitNumber: json['unit_number']?.toString() ?? '',
    );
  }
}

class MpesaNotificationTenant {
  final int id;
  final String? name;
  final String? email;
  final String? phone;

  MpesaNotificationTenant({
    required this.id,
    this.name,
    this.email,
    this.phone,
  });

  factory MpesaNotificationTenant.fromJson(Map<String, dynamic> json) {
    return MpesaNotificationTenant(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}

class MpesaNotificationProperty {
  final int id;
  final String name;

  MpesaNotificationProperty({
    required this.id,
    required this.name,
  });

  factory MpesaNotificationProperty.fromJson(
      Map<String, dynamic> json) {
    return MpesaNotificationProperty(
      id: json['id'],
      name: json['name'] ?? '',
    );
  }
}