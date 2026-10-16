import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:hub/config/config.dart';
import 'package:intl/intl.dart';


class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<DashboardMetrics?> fetchDashboardMetrics(int userId) async {
    try {
      final token = await getToken(); // from shared prefs / secure storage

      final response = await http.get(
        Uri.parse('$dashboard/$userId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DashboardMetrics.fromJson(data);
      } else {
        //print('Dashboard error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      //print('Exception: $e');
      return null;
    }
  }

  Future<DashboardMetrics?> fetchDashboardMetricsData() async {
    try {
      final userId = await getUserId(); // from shared preferences
      final data = await fetchDashboardMetrics(userId);
      return data;
    } catch (e) {
      //print('Error fetching occupancy: $e');
      return null;
    }
  }

  Future<List<RecentPayment>> fetchRecentPayments(int userId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$recentPayments/$userId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => RecentPayment.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load payments');
    }
  }

  Future<List<RecentPayment>> fetchRecentPaymentsData() async {
    try {
      final userId = await getUserId(); // from shared preferences
      final data = await fetchRecentPayments(userId);
      return data;
    } catch (e) {
      //print('Error fetching occupancy: $e');
      return [];
    }
  }

  Future<ApiResponse> createProperty({required String name,required String type,required String location,required int totalUnits,}) async {
    ApiResponse apiResponse = ApiResponse();
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse(addProperty),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // same token logic you use elsewhere
        },
        body: {
          'name': name,
          'type': type,
          'location': location,
          'total_units': totalUnits.toString(),
        },
      );

      switch (response.statusCode) {
        case 201:
        case 200:
          final body = jsonDecode(response.body);
          apiResponse.data = Nest.fromJson(body['property']);
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

  Future<List<Nest>> fetchProperties(int userId) async {
    try {
      final token = await getToken(); // same token method you use elsewhere

      final response = await http.get(
        Uri.parse('$myProperty/$userId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        final List list = body['data'];

        return list.map((e) => Nest.fromJson(e)).toList();
      } else {
        //print('Property fetch failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      //print('Property exception: $e');
      return [];
    }
  }

  Future<List<Nest>> fetchPropertiesData() async {
    try {
      final userId = await getUserId(); // from shared preferences
      final data = await fetchProperties(userId);
      return data;
    } catch (e) {
      //print('Error fetching occupancy: $e');
      return [];
    }
  }

  Future<List<PropertyOccupancyResponse>> fetchOccupancy(int userID) async {
    try {
      final token = await getToken();

      //print('User ID: $userID');
      //print('Token: ${token.substring(0, 10)}...');

      final url = '$rates/$userID';
      //print('URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      //print('Status Code: ${response.statusCode}');
      //print('Raw Body: ${response.body}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        //print('Decoded Length: ${data.length}');
        //print('First Item: ${data.isNotEmpty ? data.first : "EMPTY"}');

        final result = data
            .map((json) => PropertyOccupancyResponse.fromJson(json))
            .toList();

        //print('Parsed Models: ${result.length}');


        return result;
      } else {
        //print('❌ Server Error');

        return [];
      }
    } catch (e) {
      //print('❌ Exception: $e');
      //print(stack.toString());

      return [];
    }
  }

  Future<List<PropertyOccupancyResponse>> fetchPropertyOccupancy(int userId) async {
    final url = Uri.parse('$baseUrl/api/property-occupancy/$userId');

    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer YOUR_TOKEN_HERE', // Add auth if needed
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => PropertyOccupancyResponse.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Fetch occupancy data for the logged-in user
  Future<List<PropertyOccupancyResponse>> fetchOccupancyData() async {
    try {
      final userId = await getUserId(); // from shared preferences
      final data = await fetchUserOccupancy(userId);
      return data;
    } catch (e) {
      //print('Error fetching occupancy: $e');
      return [];
    }
  }

  Future<List<PropertyOccupancyResponse>> fetchUserOccupancy(int userId) async {
    final userId = await getUserId();
    return fetchOccupancy(userId);
  }

  Future<List<RevenueMonth>> fetchTotalRevenue(int userId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$allRevenue/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List months = body['revenue_by_month'];

      return months.map((e) => RevenueMonth.fromJson(e)).toList();
    }

    return [];
  }

  // Fetch revenue data for the logged-in user
  Future<List<RevenueMonth>> fetchRevenueData() async {
    try {
      final userId = await getUserId(); // from shared preferences
      final data = await fetchTotalRevenue(userId);
      return data;
    } catch (e) {
      //print('Error fetching occupancy: $e');
      return [];
    }
  }

  Future<List<RevenueMonth>> fetchTotalUserRevenue(int userId) async {
    final userId = await getUserId();
    return fetchTotalRevenue(userId);
  }

  Future<UnitDetails> fetchUnitDetails(int unitId) async {
    try {
      final token = await getToken();

      final response = await http.get(
        Uri.parse('$unitDetails/$unitId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      //print('Unit Details status: ${response.statusCode}');
      //print('Unit Details body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UnitDetails.fromJson(data);
      } else {
        throw Exception('Failed to load unit details');
      }
    } catch (e) {
      //print('Error fetching unit details: $e');
      rethrow;
    }
  }

  Future<ApiResponse> createInvoice({
    required int tenantId,
    required double service,
    required double refNo,
    required String invoiceMonth,
  }) async {
    ApiResponse apiResponse = ApiResponse();

    try {
      // Get token
      final token = await getToken();
      final uri = Uri.parse(invoice);

      // Parse and format the date
      String formattedDate;
      try {
        final date = DateFormat('MMMM d, yyyy').parse(invoiceMonth);
        formattedDate = DateFormat('yyyy-MM-dd').format(date);
      } catch (e) {
        apiResponse.error = 'Invalid date format. Please use format: Month Day, Year (e.g., March 5, 2026)';
        return apiResponse;
      }

      // Prepare request body
      final Map<String, String> requestBody = {
        'tenant_id': tenantId.toString(),
        'service': service.toString(),
        'invoice_date': formattedDate,
        'ref': refNo.toString(),
      };

      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      // Handle response based on status code
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          apiResponse.data = jsonDecode(response.body);
        } catch (e) {
          apiResponse.error = 'Failed to parse server response';
        }
        return apiResponse;
      }

      // Handle error responses
      try {
        final decoded = jsonDecode(response.body);

        if (response.statusCode == 422 && decoded is Map) {
          // Handle validation errors
          if (decoded.containsKey('errors') && decoded['errors'] is Map) {
            final errors = decoded['errors'] as Map;
            final firstError = errors.values.first;
            apiResponse.error = firstError is List && firstError.isNotEmpty
                ? firstError[0].toString()
                : firstError.toString();
          } else if (decoded.containsKey('message')) {
            apiResponse.error = decoded['message'].toString();
          } else {
            apiResponse.error = 'Validation error occurred';
          }
        } else if (decoded is Map && decoded.containsKey('message')) {
          apiResponse.error = decoded['message'].toString();
        } else {
          apiResponse.error = _getDefaultErrorMessage(response.statusCode);
        }
      } catch (e) {
        apiResponse.error = _getDefaultErrorMessage(response.statusCode);
      }
    } catch (e) {
      if (e is http.ClientException) {
        apiResponse.error = 'Network error - please check your connection';
      } else {
        apiResponse.error = 'An unexpected error occurred';
      }
    }

    return apiResponse;
  }

  String _getDefaultErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400: return 'Bad request - invalid parameters';
      case 401: return 'Session expired - please login again';
      case 403: return 'You do not have permission to create invoices';
      case 404: return 'Invoice service not found';
      case 500: return 'Server error - please try again later';
      default: return 'Something went wrong ($statusCode)';
    }
  }
  //Use for Dashboard pop-up dialog
  Future<PropertyResponse> fetchPropertyResponse(int userId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$dialog/$userId'), // Adjust URL to your endpoint
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return PropertyResponse.fromJson(data);
      } else {
        throw Exception('Failed to load properties: ${response.statusCode}');
      }
    } catch (e) {
      //print('Error fetching property response: $e');
      rethrow;
    }
  }


  Future<ApiResponse> createMaintenanceRequest({
    required String propertyName,
    required String houseNo,
    required String subject,
    required String description,
  }) async {
    ApiResponse apiResponse = ApiResponse();

    try {
      final token = await getToken();
      final url = Uri.parse(addMaintenance);

      final requestBody = {
        'name': propertyName,
        'house_no': houseNo,
        'subject': subject,
        'description': description,
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      switch (response.statusCode) {
        case 201:
        case 200:
          try {
            final body = jsonDecode(response.body);

            // Try common paths for data
            dynamic dataToParse;

            if (body is Map<String, dynamic>) {
              // Look in standard locations
              dataToParse = body['data'] ?? body['property'] ?? body;
            } else {
              dataToParse = body;
            }

            if (dataToParse != null) {
              apiResponse.data = MaintenanceRequest.fromJson(dataToParse);
            } else {
              apiResponse.error = 'No valid data found in response.';
            }
          } catch (parseError, stackTrace) {
            apiResponse.error = 'Error parsing server response: ${parseError.toString()}';
          }
          break;

        case 422:
          try {
            final responseBody = jsonDecode(response.body);
            final errors = responseBody['errors'];

            if (errors != null && errors.isNotEmpty) {
              final firstError = errors.values.first;
              apiResponse.error = firstError is List ? firstError[0] : firstError.toString();
            } else {
              apiResponse.error = 'Validation failed';
            }
          } catch (e) {
            apiResponse.error = 'Validation failed';
          }
          break;

        case 401:
          apiResponse.error = 'Unauthorized';
          break;

        default:
          apiResponse.error = 'Something went wrong (Status: ${response.statusCode})';
      }

    } catch (e, stackTrace) {
      print("💥 Network/API error: $e\nStack: $stackTrace");
      apiResponse.error = 'Server error: ${e.toString()}';
    }

    return apiResponse;
  }



  Future<List<MaintenanceIssue>> fetchMaintenanceIssues() async {
    try {
      final token = await getToken();

      final uri = Uri.parse(maintenanceIssues);


      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          final List<dynamic> fixesList = data['data'];
          return fixesList.map((e) => MaintenanceIssue.fromJson(e)).toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      throw Exception('Failed to load maintenance issues: $e');
    }
  }

  Future<void> updateMaintenanceIssueStatus(int issueId, String newStatus) async {
    try {
      final url = Uri.parse('$updateMaintenanceStatus/$issueId');

      final token = await getToken();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // Required for authentication
        },
        body: jsonEncode({
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        // Success - status updated
        final jsonResponse = jsonDecode(response.body);
        //print('Success: ${jsonResponse['message']}');
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Maintenance issue not found');
      } else if (response.statusCode == 403) {
        throw Exception('Unauthorized to update this maintenance issue');
      } else if (response.statusCode == 400) {
        final errorResponse = jsonDecode(response.body);
        throw Exception(errorResponse['message'] ?? 'Invalid status value');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else {
        final errorResponse = jsonDecode(response.body);
        throw Exception(errorResponse['message'] ?? 'Failed to update issue status');
      }
    } catch (e) {
      //print('Network error in updateMaintenanceIssueStatus: $e');
      throw Exception('Network error: $e');
    }
  }

  //Notifications

  Future<List<MpesaTransaction>> fetchMpesaNotifications(String businessShortCode) async {
    try {
      final token = await getToken();

      final uri = Uri.parse(
        '$mpesaNotifications/$businessShortCode',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic> &&
            data.containsKey('data')) {
          final List<dynamic> transactionsList = data['data'];

          return transactionsList
              .map((e) => MpesaTransaction.fromJson(e))
              .toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(
        'Failed to load M-Pesa notifications: $e',
      );
    }
  }

  Future<List<MaintenanceNotification>> fetchMaintenanceNotifications() async {
    try {
      final token = await getToken();

      final uri = Uri.parse(maintenanceNotifications);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      final data = decoded['data'];

      if (data is! List) {
        throw Exception(
          'Invalid maintenance data format: ${data.runtimeType}',
        );
      }

      final notifications = data
          .whereType<Map<String, dynamic>>()
          .map((json) => MaintenanceNotification.fromJson(json))
          .toList();

      return notifications;
    } catch (e) {
      throw Exception('Failed to load maintenance issues: $e');
    }
  }

  Future<List<OverdueNotification>> fetchOverdueNotifications() async {
    try {
      final token = await getToken();

      final uri = Uri.parse(overdueNotifications);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic> &&
            data.containsKey('data')) {

          final List<dynamic> overdueList = data['data'];

          return overdueList
              .map((e) => OverdueNotification.fromJson(e))
              .toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(
        'Failed to load overdue payments: $e',
      );
    }
  }

  // services/api_service.dart

  Future<List<NewTenant>> fetchTenantsByProperty(int propertyId) async {
    try {
      final token = await getToken();

      final uri = Uri.parse('$dialog/$propertyId');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );


      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
        jsonDecode(response.body);

        // The API returns units at the top level
        final List<dynamic> units =
            jsonResponse['units'] ?? [];

        debugPrint('Units found: ${units.length}');

        final List<NewTenant> tenants = [];

        for (final unit in units) {
          debugPrint('Processing unit: ${unit['unit_number']}');

          final tenant = unit['tenant'];

          if (tenant != null) {
            // Add unit information to tenant JSON
            final tenantData = Map<String, dynamic>.from(tenant);

            tenantData['unit_number'] = unit['unit_number'];
            tenantData['unit_id'] = unit['id'];

            debugPrint(
              'Tenant found: ${tenantData['name']} '
                  '(${tenantData['unit_number']})',
            );

            tenants.add(
              NewTenant.fromJson(tenantData),
            );
          }
        }

        return tenants;
      }

      throw Exception(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e, stackTrace) {
      debugPrint('FETCH TENANTS ERROR: $e');
      debugPrint(stackTrace.toString());

      throw Exception(
        'Failed to load tenants: $e',
      );
    }
  }

  Future<Map<String, dynamic>> sendOverdueReminder(int invoiceId) async {
    try {
      final token = await getToken();

      final uri = Uri.parse('$overdueReminder/$invoiceId/reminder');


      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );


      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        return {
          'success': true,
          'message': 'Reminder submitted successfully.',
        };
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw Exception(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {


      throw Exception(
        'Failed to send overdue reminder: $e',
      );
    }
  }
}


