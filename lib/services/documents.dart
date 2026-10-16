import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:hub/config/constants.dart';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';

class DocumentService {
  final String baseUrl;

  DocumentService({
    required this.baseUrl,
  });

  // =====================================================
  // 📥 GET DOCUMENTS
  // =====================================================
  Future<List<Document>> fetchDocuments({
    required int propertyId,
    String? category,
    String? search,
  }) async {
    final queryParameters = <String, String>{
      'property_id': propertyId.toString(),
    };

    if (category != null && category.trim().isNotEmpty) {
      queryParameters['category'] = category.trim();
    }

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final uri = Uri.parse(myDocuments).replace(
      queryParameters: queryParameters,
    );

    //debugPrint('📄 Fetching documents from: $uri');

    try {
      final token = await getToken();

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      //debugPrint('📄 Documents response status: ${response.statusCode}',);
      //debugPrint('📄 Documents response body: ${response.body}',);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch documents: '
              '${response.statusCode} ${response.reasonPhrase ?? ''}\n'
              '${response.body}',
        );
      }

      return _parseDocumentsResponse(response.body);
    } catch (e, stackTrace) {
      //debugPrint('❌ Documents fetch error: $e');
      //debugPrint('$stackTrace');

      throw Exception(
        'Failed to fetch documents: $e',
      );
    }
  }

  // =====================================================
  // 📄 PARSE DOCUMENT RESPONSE
  // =====================================================
  List<Document> _parseDocumentsResponse(
      String responseBody,
      ) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid documents response: expected JSON object.',
      );
    }

    final data = decoded['data'];

    if (data == null) {
      //debugPrint('⚠️ Documents API returned no "data" field.',);
      return <Document>[];
    }

    if (data is! List) {
      throw Exception(
        'Invalid documents response: "data" is not a list.',
      );
    }

    final documents = <Document>[];

    for (final item in data) {
      if (item is! Map) {
        //debugPrint('⚠️ Skipping invalid document item: $item',);
        continue;
      }

      try {
        final json = Map<String, dynamic>.from(item);

        //debugPrint('📄 Parsing document: ${json['id']}',);

        /*
         * IMPORTANT
         *
         * The API returns:
         *
         *   "id":
         *   "documents/invoice/Zen Apartments/Ian Wachira/invoice_835606.pdf"
         *
         * Therefore Document.id MUST be String.
         */
        final document = Document.fromJson(json);
        documents.add(document);

        //debugPrint('✅ Parsed document: ${document.name}',);
      } catch (e, stackTrace) {
        //debugPrint('❌ Failed to parse document: $e',);
        //debugPrint('Document JSON: $item',);
        //debugPrint('$stackTrace',);

        /*
         * We intentionally skip only the malformed document
         * instead of failing the entire Dashboard request.
         */
      }
    }

    //debugPrint('✅ Successfully parsed ''${documents.length}/${data.length} documents.',);

    return documents;
  }

  // =====================================================
  // 📤 UPLOAD DOCUMENT
  // =====================================================
  Future<void> uploadDocument({
    required int propertyId,
    required int tenantId,
    required String name,
    required String category,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final token = await getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(addDocument),
      );

      request.headers['Accept'] = 'application/json';

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['property_id'] = propertyId.toString();
      request.fields['tenant_id'] = tenantId.toString();
      request.fields['category'] = category;
      request.fields['name'] = name;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 UPLOADING DOCUMENT');
      debugPrint('Property ID : $propertyId');
      debugPrint('Tenant ID   : $tenantId');
      debugPrint('Tenant Name : $name');
      debugPrint('Category    : $category');
      debugPrint('File        : $fileName');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      debugPrint('📥 Status   : ${response.statusCode}');
      debugPrint('📥 Response : $responseBody');

      if (response.statusCode != 200 &&
          response.statusCode != 201) {
        throw Exception(
          'Upload failed (${response.statusCode}): $responseBody',
        );
      }

      debugPrint('✅ Document uploaded successfully.');
    } catch (e, stackTrace) {
      debugPrint('❌ Upload error: $e');
      debugPrint('$stackTrace');

      throw Exception('Upload error: $e');
    }
  }

  // =====================================================
  // 🗑️ DELETE DOCUMENT
  // =====================================================

  Future<void> deleteDocument(String documentId) async {
    if (documentId.trim().isEmpty) {
      throw Exception('Document ID cannot be empty.');
    }

    final token = await getToken();

    final encodedId = Uri.encodeComponent(documentId.trim());

    final url = '$deleteDocuments/$encodedId';



    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        if (token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
    );


    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw Exception(
        'Delete failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  // =====================================================
  // 📄 FETCH DOCUMENTS - OPTIONAL FILTERS
  // =====================================================
  Future<List<Document>> fetchDocs({
    int? propertyId,
    String? category,
    String? search,
  }) async {
    final queryParameters = <String, String>{};

    if (propertyId != null) {
      queryParameters['property_id'] = propertyId.toString();
    }

    if (category != null && category.trim().isNotEmpty) {
      queryParameters['category'] = category.trim();
    }

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final uri = Uri.parse(myDocuments).replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    //debugPrint( '📄 Fetching filtered documents: $uri',);

    try {
      final token = await getToken();

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      //debugPrint('📄 Response status: ${response.statusCode}',);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch documents: '
              '${response.statusCode}\n'
              '${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      /*
       * Normal Laravel response:
       *
       * {
       *   "success": true,
       *   "count": 3,
       *   "data": [...]
       * }
       */
      if (decoded is Map<String, dynamic>) {
        return _parseDocumentsResponse(
          response.body,
        );
      }

      /*
       * Also support a raw List response if
       * another endpoint returns one.
       */
      if (decoded is List) {
        final documents = <Document>[];

        for (final item in decoded) {
          if (item is! Map) continue;

          try {
            documents.add(
              Document.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          } catch (e) {
            //debugPrint('⚠️ Failed to parse document: $e',);
          }
        }

        return documents;
      }

      throw Exception(
        'Invalid documents response format.',
      );
    } catch (e) {
      throw Exception(
        'Failed to fetch documents: $e',
      );
    }
  }

  Future<List<Document>> fetchMyDocs({
    String? category,
    String? search,
  }) async {
    try {
      final token = await getToken();

      final queryParameters = <String, String>{};

      if (category != null && category.isNotEmpty) {
        queryParameters['category'] = category;
      }

      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }

      final uri = Uri.parse(userDocuments).replace(
        queryParameters: queryParameters.isNotEmpty
            ? queryParameters
            : null,
      );

      //debugPrint('📄 Fetching current user documents: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      //debugPrint('📄 Documents status: ${response.statusCode}');

      //debugPrint('📄 Documents response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch documents: '
              '${response.statusCode}\n'
              '${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Invalid documents response format.',
        );
      }

      final data = decoded['data'];

      if (data == null) {
        return [];
      }

      if (data is! List) {
        throw Exception(
          'Invalid documents response: '
              '"data" is not a list.',
        );
      }

      return data
          .whereType<Map>()
          .map(
            (item) => Document.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();

    } catch (e) {
      //debugPrint('❌ fetchMyDocs error: $e');

      throw Exception(
        'Failed to fetch my documents: $e',
      );
    }
  }
}

// =====================================================
// 📌 DOCUMENT ENUMS
// =====================================================
enum DocumentCategory {
  receipt,
  invoice,
  lease,
  document,
  photo,
}

extension DocumentCategoryX on DocumentCategory {
  String get name {
    switch (this) {
      case DocumentCategory.receipt:
        return 'receipt';
      case DocumentCategory.invoice:
        return 'invoice';
      case DocumentCategory.lease:
        return 'lease';
      case DocumentCategory.document:
        return 'document';
      case DocumentCategory.photo:
        return 'photo';
    }
  }

  String get displayName {
    switch (this) {
      case DocumentCategory.receipt:
        return 'Receipt';
      case DocumentCategory.invoice:
        return 'Invoice';
      case DocumentCategory.lease:
        return 'Lease';
      case DocumentCategory.document:
        return 'Document';
      case DocumentCategory.photo:
        return 'Photo';
    }
  }

  static DocumentCategory fromString(
      String value,
      ) {
    switch (value.toLowerCase()) {
      case 'receipt':
        return DocumentCategory.receipt;
      case 'invoice':
        return DocumentCategory.invoice;
      case 'lease':
        return DocumentCategory.lease;
      case 'photo':
        return DocumentCategory.photo;
      default:
        return DocumentCategory.document;
    }
  }


}