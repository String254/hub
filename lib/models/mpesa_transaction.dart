class MpesaTransactionsResponse {
  final bool success;
  final String businessShortCode;
  final int count;
  final List<MpesaTransaction> data;

  MpesaTransactionsResponse({
    required this.success,
    required this.businessShortCode,
    required this.count,
    required this.data,
  });

  factory MpesaTransactionsResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    return MpesaTransactionsResponse(
      success: json['success'] ?? false,
      businessShortCode:
      json['business_short_code']?.toString() ?? '',
      count: json['count'] ?? 0,
      data: (json['data'] as List? ?? [])
          .map(
            (item) => MpesaTransaction.fromJson(
          item as Map<String, dynamic>,
        ),
      )
          .toList(),
    );
  }
}


class MpesaTransaction {
  final int id;
  final String transactionId;
  final String transactionType;
  final String transactionTime;
  final double amount;
  final String businessShortCode;
  final String billRefNumber;
  final String accountNumber;
  final String unitNumber;
  final String? invoiceNumber;
  final String? orgAccountBalance;
  final String? thirdPartyTransId;
  final String msisdn;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String createdAt;

  final MpesaUnitDetails? unit;
  final MpesaTenantDetails? tenant;
  final MpesaPropertyDetails? property;

  MpesaTransaction({
    required this.id,
    required this.transactionId,
    required this.transactionType,
    required this.transactionTime,
    required this.amount,
    required this.businessShortCode,
    required this.billRefNumber,
    required this.accountNumber,
    required this.unitNumber,
    this.invoiceNumber,
    this.orgAccountBalance,
    this.thirdPartyTransId,
    required this.msisdn,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.createdAt,
    this.unit,
    this.tenant,
    this.property,
  });

  factory MpesaTransaction.fromJson(
      Map<String, dynamic> json,
      ) {
    return MpesaTransaction(
      id: json['id'] ?? 0,

      transactionId:
      json['transaction_id']?.toString() ?? '',

      transactionType:
      json['transaction_type']?.toString() ?? '',

      transactionTime:
      json['transaction_time']?.toString() ?? '',

      amount: double.tryParse(
        json['amount']?.toString() ?? '0',
      ) ??
          0,

      businessShortCode:
      json['business_short_code']?.toString() ?? '',

      billRefNumber:
      json['bill_ref_number']?.toString() ?? '',

      accountNumber:
      json['account_number']?.toString() ?? '',

      unitNumber:
      json['unit_number']?.toString() ?? '',

      invoiceNumber:
      json['invoice_number']?.toString(),

      orgAccountBalance:
      json['org_account_balance']?.toString(),

      thirdPartyTransId:
      json['third_party_trans_id']?.toString(),

      msisdn:
      json['msisdn']?.toString() ?? '',

      firstName:
      json['first_name']?.toString() ?? '',

      middleName:
      json['middle_name']?.toString(),

      lastName:
      json['last_name']?.toString() ?? '',

      createdAt:
      json['created_at']?.toString() ?? '',

      unit: json['unit'] != null
          ? MpesaUnitDetails.fromJson(
        json['unit'] as Map<String, dynamic>,
      )
          : null,

      tenant: json['tenant'] != null
          ? MpesaTenantDetails.fromJson(
        json['tenant'] as Map<String, dynamic>,
      )
          : null,

      property: json['property'] != null
          ? MpesaPropertyDetails.fromJson(
        json['property'] as Map<String, dynamic>,
      )
          : null,
    );
  }

  String get tenantName {
    if (tenant?.name.isNotEmpty == true) {
      return tenant!.name;
    }

    final name = [
      firstName,
      middleName,
      lastName,
    ]
        .where(
          (name) =>
      name != null &&
          name.trim().isNotEmpty,
    )
        .join(' ');

    return name.isEmpty
        ? 'Unknown Tenant'
        : name;
  }

  String get propertyName {
    return property?.name ?? 'Unknown Property';
  }

  String get displayUnitNumber {
    return unit?.unitNumber ?? unitNumber;
  }
}


class MpesaUnitDetails {
  final int id;
  final String unitNumber;
  final double rentAmount;
  final String status;

  MpesaUnitDetails({
    required this.id,
    required this.unitNumber,
    required this.rentAmount,
    required this.status,
  });

  factory MpesaUnitDetails.fromJson(
      Map<String, dynamic> json,
      ) {
    return MpesaUnitDetails(
      id: json['id'] ?? 0,

      unitNumber:
      json['unit_number']?.toString() ?? '',

      rentAmount: double.tryParse(
        json['rent_amount']?.toString() ?? '0',
      ) ??
          0,

      status:
      json['status']?.toString() ?? '',
    );
  }
}


class MpesaTenantDetails {
  final int id;
  final String name;
  final String? email;
  final String? phone;

  MpesaTenantDetails({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  factory MpesaTenantDetails.fromJson(
      Map<String, dynamic> json,
      ) {
    return MpesaTenantDetails(
      id: json['id'] ?? 0,

      name:
      json['name']?.toString() ??
          'Unknown Tenant',

      email:
      json['email']?.toString(),

      phone:
      json['phone']?.toString(),
    );
  }
}


class MpesaPropertyDetails {
  final int id;
  final String name;
  final String type;
  final String location;

  MpesaPropertyDetails({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
  });

  factory MpesaPropertyDetails.fromJson(
      Map<String, dynamic> json,
      ) {
    return MpesaPropertyDetails(
      id: json['id'] ?? 0,

      name:
      json['name']?.toString() ?? '',

      type:
      json['type']?.toString() ?? '',

      location:
      json['location']?.toString() ?? '',
    );
  }
}