/// Represents the current session's metadata.
class SessionInfo {
  final String sessionId;
  final String languageCode;
  final DateTime startedAt;
  final bool isPaused;

  SessionInfo({
    required this.sessionId,
    required this.languageCode,
    required this.startedAt,
    this.isPaused = false,
  });

  SessionInfo copyWith({
    String? sessionId,
    String? languageCode,
    DateTime? startedAt,
    bool? isPaused,
  }) {
    return SessionInfo(
      sessionId: sessionId ?? this.sessionId,
      languageCode: languageCode ?? this.languageCode,
      startedAt: startedAt ?? this.startedAt,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  @override
  String toString() {
    return 'Session(sessionId: \$sessionId, language: \$languageCode, startedAt: \$startedAt, paused: \$isPaused)';
  }
}
