import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:hub/config/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// ASSISTANT FAQ
// ============================================================

class AssistantFaq {
  final int? id;
  final String question;
  final String answer;
  final String? category;

  const AssistantFaq({
    this.id,
    required this.question,
    required this.answer,
    this.category,
  });

  factory AssistantFaq.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];

    return AssistantFaq(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      question: (json['question'] ?? json['title'] ?? json['name'] ?? '')
          .toString()
          .trim(),
      answer:
      (json['answer'] ??
          json['response'] ??
          json['content'] ??
          json['description'] ??
          '')
          .toString()
          .trim(),
      category: (json['category'] ?? json['category_name'])?.toString().trim(),
    );
  }
}

// ============================================================
// CHAT REPLY
// ============================================================

class ChatReply {
  final String reply;
  final bool chartRequested;
  final String? chartType;
  final Map<String, dynamic>? chartData;
  final List<Map<String, dynamic>> chartRecords;
  final Map<String, dynamic>? chartPeriod;
  final String? requestedStartDate;
  final String? requestedEndDate;
  final int chartRecordCount;
  final String? chartCurrency;

  // Conversation-memory support.
  final String? conversationId;

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
    this.conversationId,
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    final rawChartData = json['chart_data'];

    final Map<String, dynamic>? parsedChartData = rawChartData is Map
        ? Map<String, dynamic>.from(rawChartData)
        : null;

    final rawRecords = json['chart_records'];

    final List<Map<String, dynamic>> parsedRecords = rawRecords is List
        ? rawRecords
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList()
        : _recordsFromChartData(parsedChartData);

    final rawPeriod = json['chart_period'];

    Map<String, dynamic>? parsedPeriod;

    if (rawPeriod is Map) {
      parsedPeriod = Map<String, dynamic>.from(rawPeriod);
    } else if (parsedChartData?['period'] is Map) {
      parsedPeriod = Map<String, dynamic>.from(parsedChartData!['period']);
    }

    return ChatReply(
      reply: (json['response'] ?? json['reply'] ?? 'No response.').toString(),
      chartRequested: _toBool(json['chart_requested']),
      chartType: json['chart_type']?.toString(),
      chartData: parsedChartData,
      chartRecords: parsedRecords,
      chartPeriod: parsedPeriod,
      requestedStartDate: json['requested_start_date']?.toString(),
      requestedEndDate: json['requested_end_date']?.toString(),
      chartRecordCount:
      _toInt(json['chart_record_count']) ?? parsedRecords.length,
      chartCurrency:
      json['chart_currency']?.toString() ??
          parsedChartData?['currency']?.toString(),
      conversationId: json['conversation_id']?.toString(),
    );
  }

  static List<Map<String, dynamic>> _recordsFromChartData(
      Map<String, dynamic>? chartData,
      ) {
    if (chartData == null) return [];

    final records = chartData['data'];

    if (records is! List) return [];

    return records
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList();
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    if (value is num) return value != 0;

    return false;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}

// ============================================================
// CHATBOT SERVICE
// ============================================================

class ChatbotService {
  // Existing session keys.
  static const String _webhookUrlKey = 'ai_webhook_url';
  static const String _aiSessionTokenKey = 'ai_session_token';
  static const String _aiSessionTokenTypeKey = 'ai_session_token_type';
  static const String _aiSessionExpiresAtKey = 'ai_session_expires_at';

  // Conversation-memory key.
  static const String _conversationIdKey = 'ai_conversation_id';

  // Authenticated Laravel context endpoint.
  static const String _assistantContextUrl =
      'https://marketfella.com/public/api/ai/assistant/context';

  static String _buildAiSessionUrl() => aiSessionUrl;

  // ==========================================================
  // CONVERSATION ID
  // ==========================================================

  static Future<String?> getConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_conversationIdKey);

    if (id == null || id.trim().isEmpty) {
      return null;
    }

    return id;
  }

  // Starts a fresh local conversation.
  // Does not delete saved conversation history on the server.
  // Does not clear the authenticated AI session.
  static Future<void> startNewConversation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_conversationIdKey);
  }

  // ==========================================================
  // GET FAQS
  // ==========================================================

  static Future<List<AssistantFaq>> getFaqs() async {
    final prefs = await SharedPreferences.getInstance();

    var token = prefs.getString('ai_session_token');

    if (token == null || token.isEmpty) {
      token = await _createAiSession();
    }

    if (token == null || token.isEmpty) {
      throw Exception(
        'AI session token is missing. Please sign in again.',
      );
    }

    final url = '$baseUrl/ai/assistant/faqs';

    Future<http.Response> sendRequest(String sessionToken) {
      return http
          .get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $sessionToken',
          'Accept': 'application/json',
        },
      )
          .timeout(const Duration(seconds: 30));
    }

    var response = await sendRequest(token);

    // If the AI session has expired, create a fresh one and retry once.
    if (response.statusCode == 401) {
      final rejectedToken = token;

      await prefs.remove('ai_session_token');

      final refreshedToken = await _createAiSession();

      if (refreshedToken == null || refreshedToken.isEmpty) {
        throw Exception(
          'Unable to refresh the AI session. Please sign in again.',
        );
      }

      // Don't retry with the token the server just rejected.
      if (refreshedToken == rejectedToken) {
        throw Exception(
          'The AI session could not be refreshed. Please sign in again.',
        );
      }

      token = refreshedToken;
      response = await sendRequest(token);

      // A second 401 means refresh didn't help — surface it clearly.
      if (response.statusCode == 401) {
        await prefs.remove('ai_session_token');
        throw Exception(
          'The AI session has expired. Please sign in again.',
        );
      }
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load FAQs (HTTP ${response.statusCode}): '
            '${response.body}',
      );
    }

    // Decode as UTF-8 explicitly. `response.body` falls back to latin1
    // when the server omits a charset, which corrupts non-ASCII text.
    final String body;

    try {
      body = utf8.decode(response.bodyBytes);
    } on FormatException {
      throw Exception('The FAQ API returned invalid UTF-8 content.');
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw Exception('The FAQ API returned invalid JSON.');
    }

    if (decoded is! Map) {
      throw Exception('Invalid FAQ API response.');
    }

    final data = Map<String, dynamic>.from(decoded);

    if (data['success'] == false) {
      throw Exception(
        data['message']?.toString() ?? 'Unable to load FAQs.',
      );
    }

    final rawFaqs = data['data'];

    if (rawFaqs is! List) {
      throw Exception(
        'The FAQ API response does not contain a valid data list.',
      );
    }

    // Parse per item: skip malformed entries instead of failing the
    // whole call because of one bad row.
    final faqs = <AssistantFaq>[];

    for (final item in rawFaqs) {
      if (item is! Map) continue;

      try {
        final faq = AssistantFaq.fromJson(Map<String, dynamic>.from(item));

        if (faq.question.trim().isEmpty || faq.answer.trim().isEmpty) {
          continue;
        }

        faqs.add(faq);
      } catch (_) {
        // Swallow and skip; optionally log here.
      }
    }

    return faqs;
  }

  // ==========================================================
  // WEBHOOK URL
  // ==========================================================

  static Future<String> _getWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_webhookUrlKey);

    if (stored == null || stored.isEmpty) {
      throw Exception(
        'AI webhook URL not available. Create an AI session first.',
      );
    }

    return stored;
  }

  // ==========================================================
  // SEND MESSAGE
  // ==========================================================

  static Future<ChatReply> sendMessage({
    required String? userId,
    required String message,
  }) async {
    final aiSessionToken = await _getValidAiSessionToken();

    if (aiSessionToken == null || aiSessionToken.isEmpty) {
      throw Exception('Unable to create AI Property Manager session.');
    }

    final prefs = await SharedPreferences.getInstance();
    final webhookUrl = await _getWebhookUrl();
    final conversationId = prefs.getString(_conversationIdKey);

    final requestBody = <String, dynamic>{
      'session_id': userId ?? 'anonymous',
      'message': message,
      'ai_session_token': aiSessionToken,
    };

    // Reuse the current conversation for follow-up questions.
    if (conversationId != null && conversationId.isNotEmpty) {
      requestBody['conversation_id'] = conversationId;
    }

    final response = await http
        .post(
      Uri.parse(webhookUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('AI assistant returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Invalid chatbot response.');
    }

    final result = ChatReply.fromJson(Map<String, dynamic>.from(decoded));

    // Save a conversation ID returned by n8n.
    // If no ID is returned, preserve the existing one.
    final returnedId = result.conversationId?.trim();

    if (returnedId != null && returnedId.isNotEmpty) {
      await prefs.setString(_conversationIdKey, returnedId);
    }

    return result;
  }

  // ==========================================================
  // GET VALID AI SESSION TOKEN
  // ==========================================================

  static Future<String?> _getValidAiSessionToken() async {
    final prefs = await SharedPreferences.getInstance();

    final existingToken = prefs.getString(_aiSessionTokenKey);

    final expiresAtString = prefs.getString(_aiSessionExpiresAtKey);

    if (existingToken != null &&
        existingToken.isNotEmpty &&
        expiresAtString != null &&
        expiresAtString.isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresAtString);

      if (expiresAt != null) {
        final safeExpiry = expiresAt.subtract(const Duration(seconds: 30));

        if (DateTime.now().isBefore(safeExpiry)) {
          return existingToken;
        }
      }
    }

    return _createAiSession();
  }

  // ==========================================================
  // CREATE AI SESSION
  // ==========================================================

  static Future<String?> _createAiSession() async {
    final prefs = await SharedPreferences.getInstance();

    final authToken = prefs.getString('auth_token');


    if (authToken == null || authToken.isEmpty) {
      //debugPrint('AI session creation failed: auth_token is missing.');
      return null;
    }

    try {
      final response = await http
          .post(
        Uri.parse(_buildAiSessionUrl()),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // debugPrint(
        //   'AI session creation failed. '
        //       'HTTP ${response.statusCode}: ${response.body}',
        // );
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        // debugPrint('AI session creation failed: invalid response format.');
        return null;
      }

      final data = Map<String, dynamic>.from(decoded);

      if (data['success'] != true) {
        // debugPrint(
        //   'AI session creation failed: '
        //       '${data['message'] ?? 'Unknown server error'}',
        // );
        return null;
      }

      final sessionToken = data['session_token']?.toString();
      final tokenType = data['token_type']?.toString() ?? 'Bearer';
      final webhookUrl = data['webhook_url']?.toString();
      final expiresAt = data['expires_at']?.toString();

      if (sessionToken == null || sessionToken.isEmpty) {
        // debugPrint('AI session creation failed: session_token is missing.');
        return null;
      }

      if (webhookUrl == null || webhookUrl.isEmpty) {
        // debugPrint('AI session creation failed: webhook_url is missing.');
        return null;
      }

      await prefs.setString(_aiSessionTokenKey, sessionToken);
      await prefs.setString(_aiSessionTokenTypeKey, tokenType);
      await prefs.setString(_webhookUrlKey, webhookUrl);

      if (expiresAt != null && expiresAt.isNotEmpty) {
        await prefs.setString(_aiSessionExpiresAtKey, expiresAt);
      }

      // debugPrint('AI session created successfully.');

      return sessionToken;
    } catch (e) {
      // debugPrint('AI session creation error: $e');
      return null;
    }
  }
  // ==========================================================
  // CLEAR AI SESSION
  // ==========================================================

  static Future<void> clearAiSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_aiSessionTokenKey);
    await prefs.remove(_aiSessionTokenTypeKey);
    await prefs.remove(_aiSessionExpiresAtKey);
    await prefs.remove(_webhookUrlKey);

    // Deliberately preserve conversation history.
    // Call startNewConversation() separately when required.
  }
}