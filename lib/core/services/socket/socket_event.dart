// lib/core/services/socket/socket_event.dart
import 'dart:convert';

/// Base class for all socket events.
abstract class SocketEvent {
  /// A string tag to identify the JSON event type.
  String get type;

  /// Convert this event to a JSON-encodable map.
  Map<String, dynamic> toJson();

  /// Parse a JSON map into the correct subtype.
  static SocketEvent fromJson(Map<String, dynamic> map) {
    switch (map['type'] as String) {
      case TranscriptEvent.eventType:
        return TranscriptEvent(
          sessionId: map['sessionId'] as String,
          text: map['text'] as String,
          isFinal: map['isFinal'] as bool,
        );
      case TranslationEvent.eventType:
        return TranslationEvent(
          sessionId: map['sessionId'] as String,
          translatedText: map['translatedText'] as String,
          targetLanguage: map['targetLanguage'] as String,
        );
      case AudienceUpdateEvent.eventType:
        return AudienceUpdateEvent(
          sessionId: map['sessionId'] as String,
          totalListeners: map['totalListeners'] as int,
          languageDistribution: Map<String, int>.from(
            map['languageDistribution'] as Map? ?? {},
          ),
        );
      case SessionJoinEvent.eventType:
        return SessionJoinEvent(
          sessionId: map['sessionId'] as String,
          userId: map['userId'] as String,
          language: map['language'] as String,
        );
      case SessionLeaveEvent.eventType:
        return SessionLeaveEvent(
          sessionId: map['sessionId'] as String,
          userId: map['userId'] as String,
        );
      default:
        throw UnsupportedError('Unknown SocketEvent type: ${map['type']}');
    }
  }

  /// Helper: decode from a raw JSON string.
  static SocketEvent decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Event to transmit a transcription update.
class TranscriptEvent extends SocketEvent {
  static const eventType = 'transcript';

  @override
  String get type => eventType;

  final String sessionId;
  final String text;
  final bool isFinal;

  TranscriptEvent({
    required this.sessionId,
    required this.text,
    required this.isFinal,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'sessionId': sessionId,
    'text': text,
    'isFinal': isFinal,
  };
}

/// Event to transmit a translated message.
class TranslationEvent extends SocketEvent {
  static const eventType = 'translation';

  @override
  String get type => eventType;

  final String sessionId;
  final String translatedText;
  final String targetLanguage;

  TranslationEvent({
    required this.sessionId,
    required this.translatedText,
    required this.targetLanguage,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'sessionId': sessionId,
    'translatedText': translatedText,
    'targetLanguage': targetLanguage,
  };
}

/// Event to update audience count and language distribution.
class AudienceUpdateEvent extends SocketEvent {
  static const eventType = 'audience_update';

  @override
  String get type => eventType;

  final String sessionId;
  final int totalListeners;
  final Map<String, int> languageDistribution;

  AudienceUpdateEvent({
    required this.sessionId,
    required this.totalListeners,
    required this.languageDistribution,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'sessionId': sessionId,
    'totalListeners': totalListeners,
    'languageDistribution': languageDistribution,
  };

  /// Creates an empty audience update (no listeners).
  factory AudienceUpdateEvent.empty(String sessionId) => AudienceUpdateEvent(
    sessionId: sessionId,
    totalListeners: 0,
    languageDistribution: {},
  );
}

/// Event when a user joins a session.
class SessionJoinEvent extends SocketEvent {
  static const eventType = 'session_join';

  @override
  String get type => eventType;

  final String sessionId;
  final String userId;
  final String language;

  SessionJoinEvent({
    required this.sessionId,
    required this.userId,
    required this.language,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'sessionId': sessionId,
    'userId': userId,
    'language': language,
  };
}

/// Event when a user leaves a session.
class SessionLeaveEvent extends SocketEvent {
  static const eventType = 'session_leave';

  @override
  String get type => eventType;

  final String sessionId;
  final String userId;

  SessionLeaveEvent({required this.sessionId, required this.userId});

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'sessionId': sessionId,
    'userId': userId,
  };
}
