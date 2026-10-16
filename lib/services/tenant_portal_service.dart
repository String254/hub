import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:hub/config/config.dart';
import 'package:hub/pages/pages.dart';
import 'package:hub/services/fetch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hub/services/services.dart';

class TenantPortalAuthException implements Exception {
  final String message;

  TenantPortalAuthException(this.message);

  @override
  String toString() => message;
}

class TenantPortalService {
  final String baseUrl;

  TenantPortalService({
    required this.baseUrl,
  });

  // ------------------------------------------------------------
  // Authentication
  // ------------------------------------------------------------

  Future<TenantPortalAuthResult> authenticate(
      String accessToken,
      ) async {
    final url =
        '$baseUrl/tenant/portal/access/$accessToken';

    //debugPrint('====================================');
    //debugPrint('TENANT PORTAL AUTH');
    //debugPrint('URL: $url');
    //debugPrint('TOKEN LENGTH: $accessToken');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
      },
    );

    //debugPrint('STATUS: ${response.statusCode}');
    //debugPrint('RESPONSE: ${response.body}');
    //debugPrint('====================================');

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Unable to authenticate tenant portal.',
      );
    }

    final sessionToken =
    data['session_token']?.toString();

    final expiresAt =
    data['session_expires_at']?.toString();

    if (sessionToken == null ||
        sessionToken.isEmpty ||
        expiresAt == null ||
        expiresAt.isEmpty) {
      throw TenantPortalAuthException(
        'The server did not return a valid portal session.',
      );
    }

    await TenantPortalStorage.saveSession(
      token: sessionToken,
      expiresAt: expiresAt,
    );

    return TenantPortalAuthResult(
      user: _parseUser(data),
      sessionToken: sessionToken,
      expiresAt: DateTime.tryParse(expiresAt),
    );
  }

  // ------------------------------------------------------------
  // Current Tenant
  // ------------------------------------------------------------

  Future<TenantPortalUser> fetchMe() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tenant-portal/me',
      ),
      headers: await _authenticatedHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your portal session has expired.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['message']?.toString() ??
            'Unable to load tenant profile.',
      );
    }

    return _parseUser(data);
  }

  // ------------------------------------------------------------
  // Logout
  // ------------------------------------------------------------

  Future<void> logout() async {
    final token =
    await TenantPortalStorage.getSessionToken();

    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse(
            '$baseUrl/tenant-portal/logout',
          ),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (_) {
        // Even if the API request fails,
        // local session should still be cleared.
      }
    }

    await TenantPortalStorage.clearSession();
  }

  // ------------------------------------------------------------
  // Invoices
  // ------------------------------------------------------------

  Future<List<TenantInvoice>> fetchInvoices() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tenant-portal/invoices',
      ),
      headers: await _authenticatedHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your tenant portal session has expired.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Unable to load your invoices.',
      );
    }

    final invoicesJson = data['invoices'];

    if (invoicesJson is! List) {
      return [];
    }

    return invoicesJson
        .whereType<Map>()
        .map(
          (item) => TenantInvoice.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }

  Future<TenantInvoice> fetchInvoice(
      int invoiceId,
      ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tenant-portal/invoices/$invoiceId',
      ),
      headers: await _authenticatedHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your portal session has expired.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['message']?.toString() ??
            'Failed to load invoice.',
      );
    }

    return TenantInvoice.fromJson(
      Map<String, dynamic>.from(
        data['invoice'],
      ),
    );
  }

  // ------------------------------------------------------------
  // Headers
  // ------------------------------------------------------------

  Future<Map<String, String>>
  _authenticatedHeaders() async {
    final token =
    await TenantPortalStorage.getSessionToken();

    if (token == null || token.isEmpty) {
      throw TenantPortalAuthException(
        'Tenant portal session not found.',
      );
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  TenantPortalUser _parseUser(
      Map<String, dynamic> data,
      ) {
    final tenant = Map<String, dynamic>.from(
      data['tenant'] ?? {},
    );

    final unit = Map<String, dynamic>.from(
      data['unit'] ?? {},
    );

    final property = Map<String, dynamic>.from(
      data['property'] ?? {},
    );

    return TenantPortalUser.fromJson({
      ...tenant,
      'unit': unit,
      'property': property,
    });
  }

  Map<String, dynamic> _decodeResponse(
      http.Response response,
      ) {
    try {
      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'message': 'Invalid server response.',
      };
    } catch (_) {
      return {
        'message': response.body.isNotEmpty
            ? response.body
            : 'Unable to process server response.',
      };
    }
  }

  Future<TenantDashboard> fetchDashboard() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tenant-portal/dashboard',
      ),
      headers: await _authenticatedHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your tenant portal session has expired.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Unable to load your dashboard.',
      );
    }

    return TenantDashboard.fromJson(data);
  }

  Future<TenantMaintenanceListResponse> fetchMaintenance() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tenant-portal/maintenance',
      ),
      headers: await _authenticatedHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your session has expired.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ??
            'Failed to load maintenance requests.',
      );
    }

    return TenantMaintenanceListResponse.fromJson(
      data,
    );
  }

  Future<TenantMaintenance> fetchMaintenanceDetail(
      int id,
      ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tenant-portal/maintenance/$id',
      ),
      headers: await _authenticatedHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your session has expired.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ??
            'Failed to load maintenance request.',
      );
    }

    return TenantMaintenance.fromJson(
      Map<String, dynamic>.from(
        data['maintenance'] ?? {},
      ),
    );
  }

  Future<TenantMaintenance> submitMaintenance({
    required String subject,
    required String description,
    List<MaintenancePhotoPayload> photos = const [],
  }) async {
    final headers = await _authenticatedHeaders();

    final body = <String, dynamic>{
      'subject': subject,
      'description': description,
      'photos': photos
          .map(
            (photo) => photo.toJson(),
      )
          .toList(),
    };

    final response = await http.post(
      Uri.parse(
        '$baseUrl/tenant-portal/maintenance',
      ),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your session has expired.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['message']?.toString() ??
            'Failed to submit maintenance request.',
      );
    }

    return TenantMaintenance.fromJson(
      Map<String, dynamic>.from(
        data['maintenance'] ?? {},
      ),
    );
  }

  Future<List<TenantDocument>> fetchDocuments() async {
    final url = '$baseUrl/tenant-portal/documents';

    final headers = await _authenticatedHeaders();

    late http.Response response;

    try {
      response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
    } catch (e, stackTrace) {
      rethrow;
    }

    late dynamic data;

    try {
      data = _decodeResponse(response);
    } catch (e, stackTrace) {
      rethrow;
    }

    // ------------------------------------------------------------
    // 401 - SESSION EXPIRED
    // ------------------------------------------------------------

    if (response.statusCode == 401) {
      await TenantPortalStorage.clearSession();

      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Your tenant portal session has expired.',
      );
    }

    // ------------------------------------------------------------
    // OTHER HTTP ERRORS
    // ------------------------------------------------------------

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TenantPortalAuthException(
        data['message']?.toString() ??
            'Unable to load your documents.',
      );
    }

    // ------------------------------------------------------------
    // DOCUMENTS
    // ------------------------------------------------------------

    final documentsJson = data['documents'];

    if (documentsJson is! List) {
      return [];
    }

    final documents = <TenantDocument>[];

    for (var i = 0; i < documentsJson.length; i++) {
      final item = documentsJson[i];

      if (item is! Map) {
        continue;
      }

      try {
        final documentJson = Map<String, dynamic>.from(item);

        final document = TenantDocument.fromJson(documentJson);

        documents.add(document);
      } catch (e, stackTrace) {
        // Skip malformed document.
      }
    }

    return documents;
  }


  Future<String> _getPortalToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token =
    prefs.getString('tenant_portal_session_token');

    if (token == null || token.isEmpty) {
      throw Exception(
        'Tenant portal session has expired. Please log in again.',
      );
    }

    return token;
  }

  // ------------------------------------------------------------
  // Get tenant portal session token
  // ------------------------------------------------------------

  // ------------------------------------------------------------
  // Initiate M-PESA STK Push for an invoice
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> initiateInvoicePayment(
      int invoiceId,
      ) async {
    final token = await _getPortalToken();

    final url = Uri.parse(
      '$baseUrl/tenant-portal/invoices/$invoiceId/pay',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 25));

    Map<String, dynamic> data;

    try {
      data = jsonDecode(response.body)
      as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Invalid response from payment server '
            '(${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['message'] ??
            'Unable to initiate M-PESA payment '
                '(${response.statusCode}).',
      );
    }

    if (data['success'] != true) {
      throw Exception(
        data['message'] ??
            'Unable to initiate M-PESA payment.',
      );
    }

    return data;
  }

  // ------------------------------------------------------------
  // Check M-PESA transaction status
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getPaymentStatus(
      int transactionId,
      ) async {
    final url = Uri.parse(
      '$baseUrl/tenant-portal/payments/$transactionId',
    );

    final response = await http.get(
      url,
      headers: await _authenticatedHeaders(),
    ).timeout(const Duration(seconds: 15));

    Map<String, dynamic> data;

    try {
      data = jsonDecode(response.body)
      as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Invalid response from payment server '
            '(${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['message'] ??
            'Unable to check payment status '
                '(${response.statusCode}).',
      );
    }

    if (data['success'] != true) {
      throw Exception(
        data['message'] ??
            'Unable to check payment status.',
      );
    }

    return data;
  }
}

class TenantPortalAuthResult {
  final TenantPortalUser user;
  final String sessionToken;
  final DateTime? expiresAt;

  TenantPortalAuthResult({
    required this.user,
    required this.sessionToken,
    required this.expiresAt,
  });
}

class MaintenancePhotoPayload {
  final String filename;
  final String mimeType;
  final String data;

  const MaintenancePhotoPayload({
    required this.filename,
    required this.mimeType,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'mime_type': mimeType,
      'data': data,
    };
  }
}



