// lib/features/session_host/domain/entities/session_info.dart

import 'package:flutter/foundation.dart';

@immutable
class SessionInfo {
  /// Unique identifier for this session (used as join code)
  final String sessionId;

  /// Language code the speaker chose (e.g. “en”, “es”)
  final String languageCode;

  /// When this session was created
  final DateTime createdAt;

  const SessionInfo({
    required this.sessionId,
    required this.languageCode,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionInfo &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          languageCode == other.languageCode &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      sessionId.hashCode ^ languageCode.hashCode ^ createdAt.hashCode;

  @override
  String toString() {
    return 'SessionInfo(sessionId: $sessionId, languageCode: $languageCode, createdAt: $createdAt)';
  }
}
