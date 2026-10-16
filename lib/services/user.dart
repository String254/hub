import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hub/models/api_response.dart';
import 'package:hub/models/user.dart';
import 'package:hub/config/config.dart';

// --- User Login ---
Future<ApiResponse> login(String email, String password) async {
  ApiResponse apiResponse = ApiResponse();

  try {
    final response = await http.post(
      Uri.parse(loginUrl),
      headers: {'Accept': 'application/json'},
      body: {
        'email': email,
        'password': password,
      },
    );

    final Map<String, dynamic> responseBody = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // 🔴 IMPORTANT: pass ONLY responseBody['user']
      final user = User.fromJson(responseBody['user']);

      user.token = responseBody['access_token'];

      await _saveUserDetails(user, user.token!);
      apiResponse.data = user;
    }
    else if (response.statusCode == 422) {
      final errors = responseBody['errors'];
      apiResponse.error = errors[errors.keys.first][0];
    }
    else {
      apiResponse.error = responseBody['message'] ?? somethingWentWrong;
    }
  } catch (e) {
    // TEMP: expose real error
    apiResponse.error = e.toString();
  }
  return apiResponse;
}



// --- User Logout ---
Future<ApiResponse> logout() async {
  ApiResponse apiResponse = ApiResponse();
  try {
    String token = await getToken();
    final response = await http.post(
      Uri.parse(loginUrl), // Make sure logoutURL is defined in your config.dart
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );

    switch (response.statusCode) {
      case 200:
        // On success, clear the local user data
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        apiResponse.data = jsonDecode(response.body)['message'];
        break;
      case 403:
        apiResponse.error = jsonDecode(response.body)['message'];
        break;
      default:
        apiResponse.error = somethingWentWrong;
        break;
    }
  } catch (e) {
    apiResponse.error = serverError;
  }

  return apiResponse;
}


// --- Forgot Password ---
Future<ApiResponse> forgotPassword(String email) async {
  ApiResponse apiResponse = ApiResponse();

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
      }),
    );

    final Map<String, dynamic> responseBody =
    jsonDecode(response.body);

    if (response.statusCode == 200) {
      apiResponse.data =
          responseBody['message'] ??
              'Password reset instructions have been sent to your email.';
    } else if (response.statusCode == 422) {
      apiResponse.error =
          responseBody['message'] ??
              'Unable to process password reset request.';
    } else {
      apiResponse.error =
          responseBody['message'] ??
              somethingWentWrong;
    }
  } catch (e) {
    apiResponse.error = serverError;
  }

  return apiResponse;
}
// --- Helper Functions ---

// Get User ID from SharedPreferences
Future<int> getUserId() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getInt('userId') ?? 0;
}

// Get Token from SharedPreferences
Future<String> getToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('token') ?? '';
}

// Save user details and token to SharedPreferences
Future<void> _saveUserDetails(User user, String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Save user data
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    await prefs.setString('auth_token', token);

    // 🔴 Save user ID separately
    await prefs.setString('user_id', user.id.toString());

    // Save other user details you might need
    await prefs.setString('name', user.name ?? '');
    await prefs.setString('email', user.email ?? '');
    await prefs.setString('phone', user.phone ?? '');

    //print('Saved user ID: ${user.id}');
  } catch (e) {
    //print('Error saving user details: $e');
  }
}

