// lib/core/services/speech_to_text/speech_to_text_service.dart

import 'speech_result.dart';

abstract class ISpeechToTextService {
  /// Initializes the speech recognition plugin and checks permissions.
  /// Returns true if initialization succeeds.
  Future<bool> initialize();

  /// Starts listening for speech and emits transcription results.
  /// [onResult] is called on every partial or final result.
  /// [onError] is called if any exception occurs during streaming.
  Future<void> startListening({
    required void Function(SpeechResult result) onResult,
    required void Function(Exception error) onError,
  });

  /// Stops listening and finalizes the current transcription.
  Future<void> stopListening();

  /// Cancels the current listening session without producing a final result.
  Future<void> cancel();

  /// Returns true if the service is actively listening.
  bool get isListening;

  /// Returns true if the device supports speech recognition.
  bool get isAvailable;

  /// Returns true if microphone permission has been granted.
  Future<bool> get hasPermission;

  /// Returns a list of supported locales for speech recognition.
  Future<List<LocaleName>> getSupportedLocales();

  /// Sets the active locale for transcription (e.g., 'en-US').
  Future<void> setLocale(String localeId);

  /// Dispose of resources and cancel any pending operations.
  void dispose();
}

/// Represents a supported locale (e.g., English-US, Spanish-MX).
class LocaleName {
  final String localeId;
  final String name;

  LocaleName({required this.localeId, required this.name});
}
