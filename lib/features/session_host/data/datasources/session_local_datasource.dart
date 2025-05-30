// lib/features/session_host/data/datasources/session_local_datasource.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes/features/session_host/data/models/session_info_model.dart';

/// Optional local cache for session info (e.g. for offline resume or quick reopen).
class SessionLocalDataSource {
  static const _kSessionInfoKey = 'cached_session_info';

  /// Persists the given [session] to local storage.
  Future<void> cacheSession(SessionInfoModel session) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(session.toJson());
    await prefs.setString(_kSessionInfoKey, jsonString);
  }

  /// Retrieves the cached session, or `null` if none exists.
  Future<SessionInfoModel?> getCachedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kSessionInfoKey);
    if (jsonString == null) return null;

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return SessionInfoModel.fromJson(jsonMap);
    } catch (_) {
      // If parsing fails, clear the bad data
      await clearCache();
      return null;
    }
  }

  /// Clears any cached session data.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionInfoKey);
  }
}
