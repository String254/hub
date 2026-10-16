import 'package:intl/intl.dart';

class TenantInvoice {
  final int id;
  final String reference;
  final DateTime? invoiceDate;
  final DateTime? dueDate;

  final TenantInvoiceTenant tenant;
  final TenantInvoiceProperty property;
  final TenantInvoiceUnit unit;

  final double rent;
  final double service;
  final double amount;
  final double paid;
  final double outstanding;

  final String status;
  final List<TenantInvoiceReceipt> receipts;

  TenantInvoice({
    required this.id,
    required this.reference,
    required this.invoiceDate,
    required this.dueDate,
    required this.tenant,
    required this.property,
    required this.unit,
    required this.rent,
    required this.service,
    required this.amount,
    required this.paid,
    required this.outstanding,
    required this.status,
    required this.receipts,
  });

  factory TenantInvoice.fromJson(Map<String, dynamic> json) {
    return TenantInvoice(
      id: _toInt(json['id']),
      reference: json['reference']?.toString() ?? '',
      invoiceDate: _toDateTime(json['created_at']),
      dueDate: _toDateTime(json['invoice_date']),
      tenant: TenantInvoiceTenant.fromJson(
        Map<String, dynamic>.from(
          json['tenant'] ?? {},
        ),
      ),
      property: TenantInvoiceProperty.fromJson(
        Map<String, dynamic>.from(
          json['property'] ?? {},
        ),
      ),
      unit: TenantInvoiceUnit.fromJson(
        Map<String, dynamic>.from(
          json['unit'] ?? {},
        ),
      ),
      rent: _toDouble(json['rent']),
      service: _toDouble(json['service']),
      amount: _toDouble(json['amount']),
      paid: _toDouble(json['paid']),
      outstanding: _toDouble(json['outstanding']),
      status: json['status']?.toString() ?? 'unpaid',
      receipts: (json['receipts'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => TenantInvoiceReceipt.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  String get formattedAmount {
    return NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    ).format(amount);
  }

  String get formattedRent {
    return NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    ).format(rent);
  }

  String get formattedService {
    return NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    ).format(service);
  }

  String get formattedPaid {
    return NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    ).format(paid);
  }

  String get formattedOutstanding {
    return NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    ).format(outstanding);
  }

  String get formattedInvoiceDate {
    if (invoiceDate == null) return '-';

    return DateFormat(
      'dd MMM yyyy',
    ).format(invoiceDate!);
  }

  String get formattedDueDate {
    if (dueDate == null) return '-';

    return DateFormat(
      'dd MMM yyyy',
    ).format(dueDate!);
  }

  bool get isPaid => status.toLowerCase() == 'paid';

  bool get isPartial => status.toLowerCase() == 'partial';

  bool get isUnpaid => status.toLowerCase() == 'unpaid';

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';

      case 'partial':
        return 'Partially Paid';

      case 'unpaid':
        return 'Unpaid';

      default:
        return status;
    }
  }
}


class TenantInvoiceTenant {
  final int id;
  final String name;
  final String email;
  final String phone;

  TenantInvoiceTenant({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory TenantInvoiceTenant.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantInvoiceTenant(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}


class TenantInvoiceProperty {
  final int id;
  final String name;
  final String location;

  TenantInvoiceProperty({
    required this.id,
    required this.name,
    required this.location,
  });

  factory TenantInvoiceProperty.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantInvoiceProperty(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }
}


class TenantInvoiceUnit {
  final int id;
  final String unitNumber;

  TenantInvoiceUnit({
    required this.id,
    required this.unitNumber,
  });

  factory TenantInvoiceUnit.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantInvoiceUnit(
      id: json['id'] ?? 0,
      unitNumber: json['unit_number']?.toString() ?? '',
    );
  }
}


class TenantInvoiceReceipt {
  final int id;
  final double amount;
  final DateTime? paymentDate;
  final String? reference;

  TenantInvoiceReceipt({
    required this.id,
    required this.amount,
    required this.paymentDate,
    required this.reference,
  });

  factory TenantInvoiceReceipt.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantInvoiceReceipt(
      id: json['id'] ?? 0,

      amount: json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(
        json['amount']?.toString() ?? '',
      ) ??
          0,

      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(
        json['payment_date'].toString(),
      )
          : null,

      reference: json['reference']?.toString(),
    );
  }

  String get formattedAmount {
    return NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    ).format(amount);
  }

  String get formattedPaymentDate {
    if (paymentDate == null) return '-';

    return DateFormat(
      'dd MMM yyyy',
    ).format(paymentDate!);
  }
}

// ─────────────────────────────────────────────
// JSON HELPERS
// ─────────────────────────────────────────────

int _toInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.toInt();
  }

  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0.0;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}