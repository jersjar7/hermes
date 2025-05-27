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
