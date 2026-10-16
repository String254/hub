class TenantDocument {
  final int id;
  final String name;
  final String title;

  final String propertyName;

  final String filePath;
  final String? fileUrl;

  final String category;
  final String type;

  final String? mimeType;
  final int? size;
  final int? fileSize;

  final int? propertyId;
  final int? unitId;
  final int? tenantId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  TenantDocument({
    required this.id,
    required this.name,
    required this.title,
    required this.propertyName,
    required this.filePath,
    this.fileUrl,
    required this.category,
    required this.type,
    this.mimeType,
    this.size,
    this.fileSize,
    this.propertyId,
    this.unitId,
    this.tenantId,
    this.createdAt,
    this.updatedAt,
  });

  factory TenantDocument.fromJson(Map<String, dynamic> json) {
    final filePath = json['file_path']?.toString() ?? '';

    final propertyName =
        json['property_name']?.toString() ?? 'Unknown Property';

    return TenantDocument(
      id: _parseInt(json['id']) ?? 0,

      name: json['name']?.toString() ?? '',

      title: json['title']?.toString() ??
          json['name']?.toString() ??
          '',

      // Laravel:
      // "property_name": "Zen Apartments"
      propertyName: propertyName,

      // Laravel:
      // "file_path": "documents/invoice/..."
      filePath: filePath,

      // Laravel:
      // "file_url": "https://.../storage/documents/invoice/..."
      fileUrl: json['file_url']?.toString(),

      category: json['category']?.toString() ??
          json['type']?.toString() ??
          '',

      type: json['type']?.toString() ??
          json['category']?.toString() ??
          '',

      mimeType: json['mime_type']?.toString(),

      size: _parseInt(json['size']),

      fileSize: _parseInt(json['file_size']),

      propertyId: _parseInt(json['property_id']),

      unitId: _parseInt(json['unit_id']),

      tenantId: _parseInt(json['tenant_id']),

      createdAt: _parseDateTime(json['created_at']),

      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'property_name': propertyName,
      'file_path': filePath,
      'file_url': fileUrl,
      'category': category,
      'type': type,
      'mime_type': mimeType,
      'size': size,
      'file_size': fileSize,
      'property_id': propertyId,
      'unit_id': unitId,
      'tenant_id': tenantId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic value) {
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  /// Stored document path.
  String get path => filePath;

  /// Filename extracted from the stored path.
  String get fileName {
    if (filePath.isEmpty) {
      return name;
    }

    final normalized = filePath.replaceAll('\\', '/');

    return normalized.split('/').last;
  }

  /// Whether this document is a PDF.
  bool get isPdf {
    final mime = mimeType?.toLowerCase();

    if (mime == 'application/pdf') {
      return true;
    }

    return fileName.toLowerCase().endsWith('.pdf');
  }
}