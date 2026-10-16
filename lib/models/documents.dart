class Document {
  final String id;
  final String name;
  final String category;
  final int? propertyId;
  final String propertyName;
  final String? tenantName;
  final String filePath;
  final String url;
  final bool fileExists;
  final String extension;
  final int size;
  final String mimeType;

  /// Created date returned by the API as an ISO datetime string.
  final DateTime? createdAt;

  /// Last modified returned by the API as a Unix timestamp.
  final int? lastModified;

  final DocumentProperty? property;

  const Document({
    required this.id,
    required this.name,
    required this.category,
    this.propertyId,
    required this.propertyName,
    this.tenantName,
    required this.filePath,
    required this.url,
    required this.fileExists,
    required this.extension,
    required this.size,
    required this.mimeType,
    this.createdAt,
    this.lastModified,
    this.property,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      // IMPORTANT:
      // The API returns the document path as the ID.
      //
      // Example:
      // documents/invoice/Zen Apartments/
      // Ian Wachira/invoice_835606.pdf
      id: json['id']?.toString() ?? '',

      name: json['name']?.toString() ?? '',

      category: json['category']?.toString() ?? '',

      propertyId: _toInt(json['property_id']),

      propertyName: json['property_name']?.toString() ?? '',

      tenantName: json['tenant_name']?.toString(),

      filePath: json['file_path']?.toString() ?? '',

      url: json['url']?.toString() ?? '',

      fileExists: json['file_exists'] == true,

      extension: json['extension']?.toString() ?? '',

      size: _toInt(json['size']) ?? 0,

      mimeType: json['mime_type']?.toString() ?? '',

      // API returns:
      // "created_at": "2026-09-19T22:02:57.000000Z"
      createdAt: _parseDate(json['created_at']),

      // API returns last_modified as a Unix timestamp.
      // Example:
      // "last_modified": 1789856298
      lastModified: _toInt(json['last_modified']),

      property: json['property'] is Map
          ? DocumentProperty.fromJson(
        Map<String, dynamic>.from(
          json['property'] as Map,
        ),
      )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'property_id': propertyId,
      'property_name': propertyName,
      'tenant_name': tenantName,
      'file_path': filePath,
      'url': url,
      'file_exists': fileExists,
      'extension': extension,
      'size': size,
      'mime_type': mimeType,
      'created_at': createdAt?.toIso8601String(),
      'last_modified': lastModified,
      'property': property?.toJson(),
    };
  }

  // =====================================================
  // DOCUMENT TYPE HELPERS
  // =====================================================

  bool get isPdf => extension.toLowerCase() == 'pdf';

  bool get isInvoice => category.toLowerCase() == 'invoice';

  bool get isReceipt => category.toLowerCase() == 'receipt';

  bool get isImage {
    return [
      'jpg',
      'jpeg',
      'png',
      'webp',
    ].contains(extension.toLowerCase());
  }

  // =====================================================
  // FILE SIZE
  // =====================================================

  String get displaySize {
    if (size < 1024) {
      return '$size B';
    }

    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }

    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // =====================================================
  // DATE HELPERS
  // =====================================================
  /// Returns the last modified date converted from
  /// the Unix timestamp returned by the API.
  DateTime? get lastModifiedDate {
    if (lastModified == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      lastModified! * 1000,
    );
  }

  /// Returns the document creation date.
  DateTime? get createdDate {
    return createdAt;
  }

  // =====================================================
  // JSON HELPERS
  // =====================================================

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  /// Parses Laravel datetime values safely.
  ///
  /// Supported examples:
  /// 2026-09-30 13:18:31
  /// 2026-09-30T13:18:31
  /// 2026-09-30T13:18:31.000000Z
  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    // Handle numeric Unix timestamps.
    if (value is int) {
      // Seconds since Unix epoch
      return DateTime.fromMillisecondsSinceEpoch(
        value * 1000,
      );
    }

    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
      );
    }

    final String dateString = value.toString().trim();

    if (dateString.isEmpty) {
      return null;
    }

    // Handle numeric timestamps returned as strings.
    final numericValue = int.tryParse(dateString);

    if (numericValue != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        numericValue * 1000,
      );
    }

    // Handle Laravel datetime:
    // 2026-09-30 13:18:31
    // 2026-09-30T13:18:31.000000Z
    return DateTime.tryParse(
      dateString.replaceFirst(' ', 'T'),
    );
  }
}

// =====================================================
// PROPERTY INFORMATION EMBEDDED IN DOCUMENT
// =====================================================

class DocumentProperty {
  final int id;
  final String name;
  final String? type;
  final String? location;
  final int? totalUnits;
  final int? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DocumentProperty({
    required this.id,
    required this.name,
    this.type,
    this.location,
    this.totalUnits,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  factory DocumentProperty.fromJson(
      Map<String, dynamic> json,
      ) {
    return DocumentProperty(
      id: _toInt(json['id']) ?? 0,

      name: json['name']?.toString() ?? '',

      type: json['type']?.toString(),

      location: json['location']?.toString(),

      totalUnits: _toInt(json['total_units']),

      userId: _toInt(json['user_id']),

      createdAt: _parseDate(json['created_at']),

      updatedAt: _parseDate(json['updated_at']),
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}