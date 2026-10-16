import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hub/models/models.dart';
import 'package:hub/config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MpesaService {

  Future<MpesaTransactionsResponse>
  getAllLandlordTransactions() async {
    final url = Uri.parse(
      '$baseUrl/payments/transactions',
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch M-PESA transactions '
            '(${response.statusCode})',
      );
    }

    final Map<String, dynamic> json =
    jsonDecode(response.body);

    if (json['success'] != true) {
      throw Exception(
        json['message'] ??
            'Unable to retrieve transactions.',
      );
    }

    return MpesaTransactionsResponse.fromJson(json);
  }

}