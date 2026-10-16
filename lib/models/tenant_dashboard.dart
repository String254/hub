import 'package:intl/intl.dart';

class TenantDashboard {
  final TenantDashboardFinancial financial;
  final List<TenantDashboardPayment> recentPayments;
  final TenantDashboardMaintenance maintenance;

  const TenantDashboard({
    required this.financial,
    required this.recentPayments,
    required this.maintenance,
  });

  factory TenantDashboard.fromJson(
      Map<String, dynamic> json,
      ) {
    final financialJson =
        json['financial'] as Map<String, dynamic>? ?? {};

    final paymentsJson =
        json['payments'] as Map<String, dynamic>? ?? {};

    final maintenanceJson =
        json['maintenance'] as Map<String, dynamic>? ?? {};

    final recentPayments =
        paymentsJson['recent'] as List<dynamic>? ?? [];

    return TenantDashboard(
      financial: TenantDashboardFinancial.fromJson(
        financialJson,
      ),
      recentPayments: recentPayments
          .whereType<Map<String, dynamic>>()
          .map(
        TenantDashboardPayment.fromJson,
      )
          .toList(),
      maintenance:
      TenantDashboardMaintenance.fromJson(
        maintenanceJson,
      ),
    );
  }
}

class TenantDashboardFinancial {
  final double monthlyRent;
  final TenantDashboardInvoice? currentInvoice;
  final double totalInvoiced;
  final double totalPaid;
  final double totalOutstanding;
  final String paymentStatus;

  const TenantDashboardFinancial({
    required this.monthlyRent,
    required this.currentInvoice,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.paymentStatus,
  });

  factory TenantDashboardFinancial.fromJson(
      Map<String, dynamic> json,
      ) {
    final currentInvoiceJson =
    json['current_invoice'];

    return TenantDashboardFinancial(
      monthlyRent: _toDouble(
        json['monthly_rent'],
      ),
      currentInvoice:
      currentInvoiceJson is Map<String, dynamic>
          ? TenantDashboardInvoice.fromJson(
        currentInvoiceJson,
      )
          : null,
      totalInvoiced: _toDouble(
        json['total_invoiced'],
      ),
      totalPaid: _toDouble(
        json['total_paid'],
      ),
      totalOutstanding: _toDouble(
        json['total_outstanding'],
      ),
      paymentStatus:
      json['payment_status']?.toString() ??
          'no_invoice',
    );
  }

  bool get hasInvoice =>
      currentInvoice != null;

  bool get isPaid =>
      paymentStatus == 'paid';

  bool get isPartial =>
      paymentStatus == 'partial';

  bool get isUnpaid =>
      paymentStatus == 'unpaid';

  bool get noInvoice =>
      paymentStatus == 'no_invoice';

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'paid':
        return 'Paid';

      case 'partial':
        return 'Partially paid';

      case 'unpaid':
        return 'Payment due';

      default:
        return 'No invoice';
    }
  }
}

class TenantDashboardInvoice {
  final int id;
  final String reference;
  final DateTime? invoiceDate;
  final double rent;
  final double service;
  final double amount;
  final double paid;
  final double outstanding;
  final String status;

  const TenantDashboardInvoice({
    required this.id,
    required this.reference,
    required this.invoiceDate,
    required this.rent,
    required this.service,
    required this.amount,
    required this.paid,
    required this.outstanding,
    required this.status,
  });

  factory TenantDashboardInvoice.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantDashboardInvoice(
      id: _toInt(json['id']),
      reference:
      json['reference']?.toString() ?? '-',
      invoiceDate:
      _parseDate(json['invoice_date']),
      rent: _toDouble(json['rent']),
      service: _toDouble(json['service']),
      amount: _toDouble(json['amount']),
      paid: _toDouble(json['paid']),
      outstanding:
      _toDouble(json['outstanding']),
      status:
      json['status']?.toString() ?? 'unpaid',
    );
  }

  String get formattedAmount =>
      _currency(amount);

  String get formattedPaid =>
      _currency(paid);

  String get formattedOutstanding =>
      _currency(outstanding);

  String get formattedRent =>
      _currency(rent);

  String get formattedService =>
      _currency(service);

  String get formattedInvoiceDate {
    if (invoiceDate == null) {
      return '-';
    }

    return DateFormat(
      'dd MMM yyyy',
    ).format(invoiceDate!);
  }

  bool get isPaid =>
      status == 'paid';

  bool get isPartial =>
      status == 'partial';

  bool get isUnpaid =>
      status == 'unpaid';
}

class TenantDashboardPayment {
  final int id;
  final double amount;
  final DateTime? paymentDate;
  final String? reference;

  const TenantDashboardPayment({
    required this.id,
    required this.amount,
    required this.paymentDate,
    required this.reference,
  });

  factory TenantDashboardPayment.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantDashboardPayment(
      id: _toInt(json['id']),
      amount: _toDouble(json['amount']),
      paymentDate:
      _parseDate(json['payment_date']),
      reference:
      json['reference']?.toString(),
    );
  }

  String get formattedAmount =>
      _currency(amount);

  String get formattedDate {
    if (paymentDate == null) {
      return '-';
    }

    return DateFormat(
      'dd MMM yyyy',
    ).format(paymentDate!);
  }
}

class TenantDashboardMaintenance {
  final int total;
  final int open;
  final List<TenantDashboardMaintenanceItem>
  recent;

  const TenantDashboardMaintenance({
    required this.total,
    required this.open,
    required this.recent,
  });

  factory TenantDashboardMaintenance.fromJson(
      Map<String, dynamic> json,
      ) {
    final recentJson =
        json['recent'] as List<dynamic>? ?? [];

    return TenantDashboardMaintenance(
      total: _toInt(json['total']),
      open: _toInt(json['open']),
      recent: recentJson
          .whereType<Map<String, dynamic>>()
          .map(
        TenantDashboardMaintenanceItem
            .fromJson,
      )
          .toList(),
    );
  }
}

class TenantDashboardMaintenanceItem {
  final int id;
  final String? title;
  final String? description;
  final String? status;
  final DateTime? createdAt;

  const TenantDashboardMaintenanceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory TenantDashboardMaintenanceItem.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantDashboardMaintenanceItem(
      id: _toInt(json['id']),
      title: json['title']?.toString(),
      description:
      json['description']?.toString(),
      status: json['status']?.toString(),
      createdAt:
      _parseDate(json['created_at']),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value.toString(),
  ) ??
      0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) return value;

  return int.tryParse(
    value.toString(),
  ) ??
      0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;

  return DateTime.tryParse(
    value.toString(),
  );
}

String _currency(double value) {
  return NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 0,
  ).format(value);
}