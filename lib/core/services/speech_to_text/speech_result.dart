// lib/core/services/speech_to_text/speech_result.dart
/// Represents the result of a speech recognition operation.
class SpeechResult {
  final String transcript;
  final bool isFinal;
  final DateTime timestamp;
  final String locale;

  SpeechResult({
    required this.transcript,
    required this.isFinal,
    required this.timestamp,
    required this.locale,
  });
}
