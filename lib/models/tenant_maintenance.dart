import 'package:intl/intl.dart';

class TenantMaintenance {
  final int id;
  final String subject;
  final String description;
  final String status;
  final List<String> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final TenantMaintenanceTenant tenant;
  final TenantMaintenanceUnit unit;
  final TenantMaintenanceProperty? property;

  const TenantMaintenance({
    required this.id,
    required this.subject,
    required this.description,
    required this.status,
    required this.photos,
    required this.createdAt,
    required this.updatedAt,
    required this.tenant,
    required this.unit,
    required this.property,
  });

  factory TenantMaintenance.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantMaintenance(
      id: _toInt(json['id']),
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',

      photos: (json['photos'] as List? ?? [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),

      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),

      tenant: TenantMaintenanceTenant.fromJson(
        Map<String, dynamic>.from(
          json['tenant'] ?? {},
        ),
      ),

      unit: TenantMaintenanceUnit.fromJson(
        Map<String, dynamic>.from(
          json['unit'] ?? {},
        ),
      ),

      property: json['property'] == null
          ? null
          : TenantMaintenanceProperty.fromJson(
        Map<String, dynamic>.from(
          json['property'],
        ),
      ),
    );
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';

      case 'resolved':
        return 'Resolved';

      case 'open':
      default:
        return 'Open';
    }
  }

  String get formattedDate {
    if (createdAt == null) {
      return 'Date unavailable';
    }

    return DateFormat(
      'dd MMM yyyy',
    ).format(createdAt!);
  }

  String get formattedDateTime {
    if (createdAt == null) {
      return 'Date unavailable';
    }

    return DateFormat(
      'dd MMM yyyy • h:mm a',
    ).format(createdAt!);
  }

  String get statusKey {
    return status.toLowerCase();
  }

  bool get isOpen => statusKey == 'open';

  bool get isInProgress => statusKey == 'in_progress';

  bool get isResolved => statusKey == 'resolved';
}


class TenantMaintenanceTenant {
  final int id;
  final String name;

  const TenantMaintenanceTenant({
    required this.id,
    required this.name,
  });

  factory TenantMaintenanceTenant.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantMaintenanceTenant(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}


class TenantMaintenanceUnit {
  final int id;
  final String unitNumber;

  const TenantMaintenanceUnit({
    required this.id,
    required this.unitNumber,
  });

  factory TenantMaintenanceUnit.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantMaintenanceUnit(
      id: _toInt(json['id']),
      unitNumber: json['unit_number']?.toString() ?? '',
    );
  }
}


class TenantMaintenanceProperty {
  final int id;
  final String name;
  final String location;

  const TenantMaintenanceProperty({
    required this.id,
    required this.name,
    required this.location,
  });

  factory TenantMaintenanceProperty.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantMaintenanceProperty(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }
}


class TenantMaintenanceSummary {
  final int total;
  final int open;
  final int inProgress;
  final int resolved;

  const TenantMaintenanceSummary({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
  });

  factory TenantMaintenanceSummary.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantMaintenanceSummary(
      total: _toInt(json['total']),
      open: _toInt(json['open']),
      inProgress: _toInt(json['in_progress']),
      resolved: _toInt(json['resolved']),
    );
  }
}


class TenantMaintenanceListResponse {
  final TenantMaintenanceSummary summary;
  final List<TenantMaintenance> maintenance;

  const TenantMaintenanceListResponse({
    required this.summary,
    required this.maintenance,
  });

  factory TenantMaintenanceListResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    return TenantMaintenanceListResponse(
      summary: TenantMaintenanceSummary.fromJson(
        Map<String, dynamic>.from(
          json['summary'] ?? {},
        ),
      ),

      maintenance: (json['maintenance'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => TenantMaintenance.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList(),
    );
  }
}


int _toInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.toInt();
  }

  return int.tryParse(
    value.toString(),
  ) ??
      0;
}


DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}