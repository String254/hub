import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hub/models/models.dart';
import 'package:hub/config/config.dart';

class ApiPropertyService {
  final String baseUrl;

  ApiPropertyService({required this.baseUrl});

  // Get token from SharedPreferences
  Future<String> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // Fetch property details
  Future<PropertyDetails> fetchPropertyDetails(int propertyId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$manageProperty/$propertyId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return PropertyDetails.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load property details');
    }
  }

  // Fetch recent payments
  Future<List<Payment>> fetchRecentPayments(int propertyId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$managePayments/$propertyId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => Payment.fromJson(json)).toList();
    } else {
      //print('Property fetch failed: ${response.statusCode}');
      return [];
    }
  }
  // Fetch property tenants
  Future<List<TenantInfo>> fetchPropertyTenants(int propertyId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$manageTenants/$propertyId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      //print('Property fetch failed: ${data}');
      return data.map((e) => TenantInfo.fromJson(e)).toList();
    } else {
      //print('Property fetch failed: ${response.statusCode}');
      return [];
    }
  }

  //Use for Manage pop-up dialog
  Future<List<UnitsDetails>> fetchPropertyUnits(int propertyId) async {
    final token = await getToken();
    final url = Uri.parse('$showUnits/$propertyId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body);
        // Convert each JSON object to UnitsDetails
        return raw
            .map((json) => UnitsDetails.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load units: ${response.statusCode}');
      }
    } on Exception catch (e) {
      // You can either re‑throw or return an empty list – choose what fits your UI
      //print('❗ fetchPropertyUnits error → $e');
      rethrow;          // let the UI decide how to handle the error
      // return [];    // alternative: silently show an empty list
    }
  }

  // Fetch revenue analytics
  Future<List<MonthlyRevenue>> fetchPropertyRevenue(int propertyId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$manageRevenue/$propertyId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['revenue_by_month'] as List;
      return data.map((json) => MonthlyRevenue.fromJson(json)).toList();
    } else {
      return [];
    }
  }

  Future<ApiResponse> createTenant({
    required int propertyId,
    required String name,
    required String email,
    required String phone,
    required String unitNo,
  }) async {
    final apiResponse = ApiResponse();
    final token = await getToken();

    try {
      final response = await http.post(
        Uri.parse('$addTenant/$propertyId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'unit_number': unitNo.trim(),
        },
      );

      //print('Create tenant status: ${response.statusCode}');
      //print('Create tenant response: ${response.body}');

      final body = jsonDecode(response.body);

      switch (response.statusCode) {
        case 200:
        case 201:
          if (body['tenant'] != null) {
            apiResponse.data = NewTenant.fromJson(body['tenant']);
          }

          apiResponse.error = null;
          break;

        case 401:
          apiResponse.error = 'Unauthorized. Please log in again.';
          break;

        case 404:
          apiResponse.error =
              body['message'] ??
                  'The specified unit or property could not be found.';
          break;

        case 422:
          final errors = body['errors'];

          if (errors is Map && errors.isNotEmpty) {
            final firstError = errors.values.first;

            if (firstError is List && firstError.isNotEmpty) {
              apiResponse.error = firstError.first.toString();
            } else {
              apiResponse.error = firstError.toString();
            }
          } else {
            apiResponse.error =
                body['message'] ??
                    'The tenant information is invalid.';
          }

          break;

        case 500:
          apiResponse.error =
              body['message'] ??
                  'The server could not create the tenant.';
          break;

        default:
          apiResponse.error =
              body['message'] ??
                  'Something went wrong. HTTP ${response.statusCode}';
      }
    } catch (e) {
      //print('Create tenant exception: $e');

      apiResponse.error =
      'Unable to connect to the server. Please try again.';
    }

    return apiResponse;
  }

  Future<ApiResponse> createUnit({
    required int id,
    required int rent,
    required String unitNo,
  }) async {
    ApiResponse apiResponse = ApiResponse();
    final token = await getToken();

    try {
      final response = await http.post(
        Uri.parse(addUnit),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: {
          'property_id': id.toString(),
          'unit_number': unitNo,
          'rent_amount': rent.toString(),
        },
      );

      switch (response.statusCode) {
        case 200:
        case 201:
          final body = jsonDecode(response.body);
          apiResponse.data = Unit.fromJson(body['unit']);
          break;

        case 422:
          final errors = jsonDecode(response.body)['errors'];
          apiResponse.error = errors.values.first[0];
          break;

        case 401:
          apiResponse.error = 'Unauthorized';
          break;

        default:
          apiResponse.error = 'Something went wrong';
      }
    } catch (e) {
      apiResponse.error = 'Server error';
    }

    return apiResponse;
  }

  Future<List<Invoice>> fetchTenantInvoices(int tenantId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$invoices/$tenantId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      return data.map((e) => Invoice.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load invoices');
    }
  }

  Future<ApiInvoiceResponse> fetchReceipt(int invoiceId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$receipt/$invoiceId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return ApiInvoiceResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load invoice: HTTP ${response.statusCode}');
    }
  }

// In your ApiPropertyService class
  Future<CreateReceiptResponse> createReceipt(CreateReceiptRequest request) async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse(newReceipt),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = jsonDecode(response.body);
      return CreateReceiptResponse.fromJson(jsonData);
    }

    // Handle error response
    String errorMessage = 'HTTP ${response.statusCode}';
    try {
      final errorJson = jsonDecode(response.body);
      errorMessage = errorJson['message'] ??
          errorJson['error'] ??
          errorJson['errors']?.toString() ??
          errorMessage;
    } catch (_) {
      // Ignore JSON parsing errors
    }

    throw Exception('Failed to create receipt: $errorMessage');
  }

  Future<Map<String, dynamic>> generateMonthlyInvoices({
    required int propertyId,
    required String propertyName,
    required DateTime invoiceDate,
    required DateTime dueDate,
    required List<Map<String, dynamic>> invoices,
  }) async {
    try {
      final uri = Uri.parse('$bulkInvoice/$propertyId');

      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'Authentication token not found. Please log in again.',
        );
      }

      if (invoices.isEmpty) {
        throw Exception(
          'No invoices have been selected for generation.',
        );
      }

      final requestBody = {
        'property_id': propertyId,
        'property_name': propertyName,
        'invoice_date': DateFormat('yyyy-MM-dd').format(invoiceDate),
        'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
        'invoice_period': DateFormat('MMMM yyyy').format(invoiceDate),
        'invoices': invoices,
      };

      debugPrint('Generating ${invoices.length} invoices...');
      debugPrint('Endpoint: $uri');

      final response = await http
          .post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception(
            'Bulk invoice generation timed out. '
                'The server may still be processing the invoices. '
                'Please check before trying again.',
          );
        },
      );

      debugPrint(
        'Bulk invoice response: ${response.statusCode}',
      );

      debugPrint(
        'Bulk invoice response body: ${response.body}',
      );

      dynamic decodedResponse;

      if (response.body.trim().isNotEmpty) {
        try {
          decodedResponse = jsonDecode(response.body);
        } catch (_) {
          decodedResponse = null;
        }
      }

      // ---------------------------------------------------------
      // SUCCESS
      // ---------------------------------------------------------

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (decodedResponse is Map) {
          return Map<String, dynamic>.from(
            decodedResponse,
          );
        }

        throw Exception(
          'Laravel returned an invalid success response.',
        );
      }

      // ---------------------------------------------------------
      // ERROR
      // ---------------------------------------------------------

      String errorMessage =
          'Bulk invoice generation failed.';

      if (decodedResponse is Map) {
        if (decodedResponse['error'] != null &&
            decodedResponse['error']
                .toString()
                .trim()
                .isNotEmpty) {
          errorMessage =
              decodedResponse['error'].toString();
        } else if (decodedResponse['message'] != null &&
            decodedResponse['message']
                .toString()
                .trim()
                .isNotEmpty) {
          errorMessage =
              decodedResponse['message'].toString();
        }

        // Laravel validation errors
        if (decodedResponse['errors'] is Map) {
          final errors =
          Map<String, dynamic>.from(
            decodedResponse['errors'],
          );

          final validationMessages =
          <String>[];

          errors.forEach((key, value) {
            if (value is List) {
              validationMessages.add(
                '$key: ${value.join(', ')}',
              );
            } else {
              validationMessages.add(
                '$key: $value',
              );
            }
          });

          if (validationMessages.isNotEmpty) {
            errorMessage =
            '$errorMessage\n\n'
                '${validationMessages.join('\n')}';
          }
        }
      } else if (response.body.trim().isNotEmpty) {
        errorMessage = response.body;
      }

      // ---------------------------------------------------------
      // HTTP STATUS
      // ---------------------------------------------------------

      switch (response.statusCode) {
        case 401:
          errorMessage =
          'Your session has expired. Please log in again.';
          break;

        case 403:
          errorMessage =
          'You are not authorized to generate invoices.';
          break;

        case 404:
          errorMessage =
          'The bulk invoice endpoint could not be found.\n\n'
              'Check the Laravel API URL and route.';
          break;

        case 422:
        // Keep Laravel's specific error.
          break;

        case 500:
        case 502:
        case 503:
        case 504:
          errorMessage =
          'The Laravel server encountered a problem '
              'while processing the invoices.\n\n'
              '$errorMessage';
          break;
      }

      throw Exception(errorMessage);
    } on TimeoutException {
      rethrow;
    } on SocketException {
      throw Exception(
        'Could not connect to the Laravel server.\n\n'
            'Check that Laravel is running and that the Flutter '
            'application is using the correct API URL.',
      );
    } catch (e) {
      rethrow;
    }
  }
}

