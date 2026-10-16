import 'dart:convert';

class MaintenanceRequest {
  final int id;
  final String name;
  final String houseNo;
  final String subject;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> photos;

  MaintenanceRequest({
    required this.id,
    required this.name,
    required this.houseNo,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.photos = const [],
  });

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) {
    return MaintenanceRequest(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      houseNo: json['house_no']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      createdAt: _parseDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
      updatedAt: _parseDateTime(
        json['updated_at'] ?? json['updatedAt'],
      ),
      photos: _parsePhotos(json['photos']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'house_no': houseNo,
      'subject': subject,
      'description': description,
      'status': status,
      'photos': photos,
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}

class MaintenanceIssue {
  final int id;
  final int? propertyId;
  final String propertyName;
  final int? unitId;
  final int? tenantId;
  final int? userId;
  final String name;
  final String houseNo;
  final String subject;
  final String description;
  final List<String> photos;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceIssue({
    required this.id,
    this.propertyId,
    required this.propertyName,
    this.unitId,
    this.tenantId,
    this.userId,
    required this.name,
    required this.houseNo,
    required this.subject,
    required this.description,
    this.photos = const [],
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceIssue.fromJson(Map<String, dynamic> json) {
    return MaintenanceIssue(
      id: _parseInt(json['id']),
      propertyId: _parseNullableInt(json['property_id']),
      propertyName: json['property_name']?.toString() ?? '',
      unitId: _parseNullableInt(json['unit_id']),
      tenantId: _parseNullableInt(json['tenant_id']),
      userId: _parseNullableInt(json['user_id']),
      name: json['name']?.toString() ?? '',
      houseNo: json['house_no']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      photos: _parsePhotos(json['photos']),
      status: json['status']?.toString() ?? 'open',
      createdAt: _parseDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
      updatedAt: _parseDateTime(
        json['updated_at'] ?? json['updatedAt'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'property_name': propertyName,
      'unit_id': unitId,
      'tenant_id': tenantId,
      'user_id': userId,
      'name': name,
      'house_no': houseNo,
      'subject': subject,
      'description': description,
      'photos': photos,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _parseNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }

  if (value != null) {
    final parsed = DateTime.tryParse(value.toString());

    if (parsed != null) {
      return parsed;
    }
  }

  return DateTime.now();
}

List<String> _parsePhotos(dynamic value) {
  if (value == null) {
    return const [];
  }

  if (value is List) {
    return value
        .where((photo) => photo != null)
        .map((photo) => photo.toString())
        .where((photo) => photo.trim().isNotEmpty)
        .toList();
  }

  return const [];
}