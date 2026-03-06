import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyGeminiApiKey = 'gemini_api_key';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserAvatar = 'user_avatar';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // API Key
  static String? getGeminiApiKey() {
    return _prefs?.getString(_keyGeminiApiKey);
  }

  static Future<bool> setGeminiApiKey(String key) async {
    return await _prefs?.setString(_keyGeminiApiKey, key) ?? false;
  }

  static Future<bool> clearGeminiApiKey() async {
    return await _prefs?.remove(_keyGeminiApiKey) ?? false;
  }

  // Auth State
  static bool isLoggedIn() {
    return _prefs?.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<void> saveUserLogin({
    required String name,
    required String email,
    String? avatarUrl,
  }) async {
    await _prefs?.setBool(_keyIsLoggedIn, true);
    await _prefs?.setString(_keyUserName, name);
    await _prefs?.setString(_keyUserEmail, email);
    if (avatarUrl != null) {
      await _prefs?.setString(_keyUserAvatar, avatarUrl);
    }
  }

  static Future<void> logout() async {
    await _prefs?.setBool(_keyIsLoggedIn, false);
    await _prefs?.remove(_keyUserName);
    await _prefs?.remove(_keyUserEmail);
    await _prefs?.remove(_keyUserAvatar);
    // Keep the API Key saved for the next time? 
    // Usually yes, unless we want a full clear.
  }

  static String? getUserName() => _prefs?.getString(_keyUserName);
  static String? getUserEmail() => _prefs?.getString(_keyUserEmail);
  static String? getUserAvatar() => _prefs?.getString(_keyUserAvatar);

  // ═══════════════════════════════════════════════════════════════════════════
  // QUOTA MONITORING
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _keyTokensToday = 'tokens_today';
  static const String _requestsToday = 'requests_today';
  static const String _keyLastQuotaDate = 'last_quota_date';

  static void _checkDayReset() {
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";
    final lastDate = _prefs?.getString(_keyLastQuotaDate) ?? '';

    if (today != lastDate) {
      _prefs?.setInt(_keyTokensToday, 0);
      _prefs?.setInt(_requestsToday, 0);
      _prefs?.setString(_keyLastQuotaDate, today);
    }
  }

  static Future<void> recordUsage(int tokens) async {
    _checkDayReset();
    final currentTokens = _prefs?.getInt(_keyTokensToday) ?? 0;
    final currentRequests = _prefs?.getInt(_requestsToday) ?? 0;
    
    await _prefs?.setInt(_keyTokensToday, currentTokens + tokens);
    await _prefs?.setInt(_requestsToday, currentRequests + 1);
  }

  static Map<String, int> getQuotaStats() {
    _checkDayReset();
    return {
      'tokens': _prefs?.getInt(_keyTokensToday) ?? 0,
      'requests': _prefs?.getInt(_requestsToday) ?? 0,
    };
  }
}
