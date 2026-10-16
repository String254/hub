import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hub/config/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// CHAT REPLY
/// ============================================================

class ChatReply {
  final String reply;

  /// Whether the AI response contains a chart.
  final bool chartRequested;

  /// Chart identifier supplied by Laravel/n8n.
  ///
  /// Examples:
  /// monthly_collections
  /// property_revenue
  /// occupancy
  /// overdue_by_tenant
  final String? chartType;

  /// Complete chart data object.
  final Map<String, dynamic>? chartData;

  /// Normalized chart records.
  final List<Map<String, dynamic>> chartRecords;

  /// Chart period.
  final Map<String, dynamic>? chartPeriod;

  /// Original requested period.
  final String? requestedStartDate;
  final String? requestedEndDate;

  /// Optional chart metadata.
  final int chartRecordCount;

  final String? chartCurrency;

  ChatReply({
    required this.reply,
    this.chartRequested = false,
    this.chartType,
    this.chartData,
    this.chartRecords = const [],
    this.chartPeriod,
    this.requestedStartDate,
    this.requestedEndDate,
    this.chartRecordCount = 0,
    this.chartCurrency,
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    final rawChartData = json['chart_data'];

    final Map<String, dynamic>? parsedChartData =
    rawChartData is Map
        ? Map<String, dynamic>.from(rawChartData)
        : null;

    final rawRecords = json['chart_records'];

    final List<Map<String, dynamic>> parsedRecords =
    rawRecords is List
        ? rawRecords
        .whereType<Map>()
        .map(
          (record) =>
      Map<String, dynamic>.from(record),
    )
        .toList()
        : _recordsFromChartData(parsedChartData);

    final rawPeriod = json['chart_period'];

    Map<String, dynamic>? parsedPeriod;

    if (rawPeriod is Map) {
      parsedPeriod = Map<String, dynamic>.from(rawPeriod);
    } else if (parsedChartData?['period'] is Map) {
      parsedPeriod = Map<String, dynamic>.from(
        parsedChartData!['period'],
      );
    }

    return ChatReply(
      reply: (json['response'] ??
          json['reply'] ??
          'No response.')
          .toString(),
      chartRequested: _toBool(
        json['chart_requested'],
      ),
      chartType: json['chart_type']?.toString(),
      chartData: parsedChartData,
      chartRecords: parsedRecords,
      chartPeriod: parsedPeriod,
      requestedStartDate:
      json['requested_start_date']?.toString(),
      requestedEndDate:
      json['requested_end_date']?.toString(),
      chartRecordCount:
      _toInt(json['chart_record_count']) ??
          parsedRecords.length,
      chartCurrency:
      json['chart_currency']?.toString() ??
          parsedChartData?['currency']?.toString(),
    );
  }

  static List<Map<String, dynamic>> _recordsFromChartData(
      Map<String, dynamic>? chartData,
      ) {
    if (chartData == null) {
      return [];
    }

    final records = chartData['data'];

    if (records is! List) {
      return [];
    }

    return records
        .whereType<Map>()
        .map(
          (record) =>
      Map<String, dynamic>.from(record),
    )
        .toList();
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    if (value is num) {
      return value != 0;
    }

    return false;
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}

/// ============================================================
/// CHATBOT SERVICE
/// ============================================================

class ChatbotService {
  static const String _webhookUrl = chatbot;

  /// SharedPreferences keys.
  static const String _aiSessionTokenKey =
      'ai_session_token';

  static const String _aiSessionExpiresAtKey =
      'ai_session_expires_at';

  /// ==========================================================
  /// SEND MESSAGE
  /// ==========================================================

  static Future<ChatReply> sendMessage({
    required String? userId,
    required String message,
  }) async {
    try {
      final aiSessionToken =
      await _getValidAiSessionToken();

      if (aiSessionToken == null ||
          aiSessionToken.isEmpty) {
        throw Exception(
          'Unable to create AI Property Manager session.',
        );
      }

      final sessionId =
          userId ?? 'anonymous';

      //debugPrint('');
      //debugPrint('━━━━━━━━ CHATBOT REQUEST ━━━━━━━━',);
      //debugPrint('Session ID: $sessionId',);
      //debugPrint('AI session token available: true',);
      //debugPrint('Message: $message',);

      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'session_id': sessionId,
          'message': message,

          // IMPORTANT:
          // This is the Laravel Sanctum AI token.
          'ai_session_token': aiSessionToken,
        }),
      );

      //debugPrint('Chatbot status: ${response.statusCode}',);
      //debugPrint('Chatbot response: ${response.body}',);

      if (response.statusCode != 200) {
        throw Exception(
          'Server returned ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception(
          'Invalid chatbot response.',
        );
      }

      return ChatReply.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (e) {
      //debugPrint('Chatbot error: $e',);

      throw Exception(
        'Could not reach the AI assistant.',
      );
    }
  }

  /// ==========================================================
  /// GET VALID AI SESSION TOKEN
  /// ==========================================================
  ///
  /// Reuses the existing 30-minute AI token.
  ///
  /// If it does not exist or has expired, a new AI session
  /// is created through Laravel.
  ///
  static Future<String?> _getValidAiSessionToken() async {
    final prefs =
    await SharedPreferences.getInstance();

    final existingToken =
    prefs.getString(_aiSessionTokenKey);

    final expiresAtString =
    prefs.getString(
      _aiSessionExpiresAtKey,
    );

    /// --------------------------------------------------------
    /// Check existing token
    /// --------------------------------------------------------

    if (existingToken != null &&
        existingToken.isNotEmpty &&
        expiresAtString != null &&
        expiresAtString.isNotEmpty) {
      final expiresAt =
      DateTime.tryParse(expiresAtString);

      if (expiresAt != null) {
        final now = DateTime.now();

        /// Give ourselves a small safety buffer so that a token
        /// does not expire while n8n is processing a request.
        final safeExpiry =
        expiresAt.subtract(
          const Duration(seconds: 30),
        );

        if (now.isBefore(safeExpiry)) {
          //debugPrint('Using existing AI session token.',);

          return existingToken;
        }
      }
    }

    /// --------------------------------------------------------
    /// Existing token missing/expired
    /// --------------------------------------------------------

    //debugPrint('AI session token missing or expired.',);

    return await _createAiSession();
  }

  /// ==========================================================
  /// CREATE AI SESSION
  /// ==========================================================
  ///
  /// Calls:
  ///
  /// POST /api/ai/session
  ///
  /// Laravel creates:
  ///
  /// Sanctum token:
  /// ai_property_manager
  ///
  /// ability:
  /// ai:property-manager
  ///
  /// lifetime:
  /// 30 minutes
  ///
  static Future<String?> _createAiSession() async {
    final prefs =
    await SharedPreferences.getInstance();

    /// IMPORTANT:
    /// Replace this with the SAME key that your existing
    /// authentication/login code uses for the Laravel
    /// Sanctum/API token.
    ///
    /// If your login code already stores the token under
    /// another key, use that exact key here.
    final authToken =
    prefs.getString('auth_token');

    if (authToken == null ||
        authToken.isEmpty) {
      //debugPrint('Cannot create AI session: ''Laravel auth token not found.',);

      return null;
    }

    try {
      final sessionUrl =
      _buildAiSessionUrl();

      //debugPrint('');
      //debugPrint('━━━━━━━━ CREATE AI SESSION ━━━━━━━━',);
      //debugPrint('URL: $sessionUrl',);

      final response = await http.post(
        Uri.parse(sessionUrl),
        headers: {
          'Authorization':
          'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      //debugPrint('AI session status: ${response.statusCode}',);

      //debugPrint('AI session response: ${response.body}',);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to create AI session. '
              'Status: ${response.statusCode}',
        );
      }

      final decoded =
      jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception(
          'Invalid AI session response.',
        );
      }

      final data =
      Map<String, dynamic>.from(decoded);

      if (data['success'] != true) {
        throw Exception(
          data['message']?.toString() ??
              'AI session creation failed.',
        );
      }

      final sessionToken =
      data['session_token']?.toString();

      if (sessionToken == null ||
          sessionToken.isEmpty) {
        throw Exception(
          'Laravel did not return session_token.',
        );
      }

      final expiresAt =
      data['expires_at']?.toString();

      /// Store the token for reuse.
      await prefs.setString(
        _aiSessionTokenKey,
        sessionToken,
      );

      if (expiresAt != null &&
          expiresAt.isNotEmpty) {
        await prefs.setString(
          _aiSessionExpiresAtKey,
          expiresAt,
        );
      }

      //debugPrint('AI session created successfully.',);
      //debugPrint('AI session expires at: $expiresAt',);

      return sessionToken;
    } catch (e) {
      //debugPrint('AI session creation error: $e',);

      return null;
    }
  }

  /// ==========================================================
  /// AI SESSION URL
  /// ==========================================================

  static String _buildAiSessionUrl() {
    return sessionToken;
  }

  /// ==========================================================
  /// CLEAR AI SESSION
  /// ==========================================================
  ///
  /// Useful when the user logs out.
  ///
  static Future<void> clearAiSession() async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.remove(
      _aiSessionTokenKey,
    );

    await prefs.remove(
      _aiSessionExpiresAtKey,
    );

    //debugPrint('AI Property Manager session cleared.',);
  }
}