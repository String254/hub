import 'package:shared_preferences/shared_preferences.dart';

class TenantPortalStorage {
  static const String _sessionTokenKey =
      'tenant_portal_session_token';

  static const String _sessionExpiryKey =
      'tenant_portal_session_expiry';

  static Future<void> saveSession({
    required String token,
    required String expiresAt,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      _sessionTokenKey,
      token,
    );

    await prefs.setString(
      _sessionExpiryKey,
      expiresAt,
    );
  }

  static Future<String?> getSessionToken() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getString(
      _sessionTokenKey,
    );
  }

  static Future<String?> getSessionExpiry() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getString(
      _sessionExpiryKey,
    );
  }

  static Future<bool> hasValidSession() async {
    final token = await getSessionToken();
    final expiry = await getSessionExpiry();

    if (token == null ||
        token.isEmpty ||
        expiry == null ||
        expiry.isEmpty) {
      return false;
    }

    final expiryDate = DateTime.tryParse(expiry);

    if (expiryDate == null) {
      return false;
    }

    return DateTime.now().isBefore(expiryDate);
  }

  static Future<void> clearSession() async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_sessionExpiryKey);
  }
}