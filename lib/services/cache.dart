import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {

  static Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(key, jsonEncode(data));
  }

  static Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    if (raw == null) return null;

    return jsonDecode(raw);
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(key);
  }
}
