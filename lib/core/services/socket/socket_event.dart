// lib/core/services/socket/socket_event.dart
/// Base class for all socket events.
abstract class SocketEvent {}

/// Event to transmit a transcription update.
class TranscriptEvent extends SocketEvent {
  final String sessionId;
  final String text;
  final bool isFinal;

  TranscriptEvent({
    required this.sessionId,
    required this.text,
    required this.isFinal,
  });
}

/// Event to transmit a translated message.
class TranslationEvent extends SocketEvent {
  final String sessionId;
  final String translatedText;
  final String targetLanguage;

  TranslationEvent({
    required this.sessionId,
    required this.translatedText,
    required this.targetLanguage,
  });
}
