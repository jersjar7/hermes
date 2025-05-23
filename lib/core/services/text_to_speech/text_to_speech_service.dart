abstract class ITextToSpeechService {
  /// Initializes the TTS engine and checks availability.
  Future<void> initialize();

  /// Speaks the given [text] aloud using the current settings.
  Future<void> speak(String text);

  /// Stops current speech output.
  Future<void> stop();

  /// Returns true if the TTS engine is currently speaking.
  Future<bool> isSpeaking();

  /// Sets the language code (e.g., 'en-US', 'es-MX').
  Future<void> setLanguage(String languageCode);

  /// Sets the speech pitch (1.0 is default).
  Future<void> setPitch(double pitch);

  /// Sets the speech rate (1.0 is default).
  Future<void> setSpeechRate(double rate);

  /// Returns a list of available languages.
  Future<List<TtsLanguage>> getLanguages();
}

/// Represents a supported TTS language/voice option.
class TtsLanguage {
  final String code;
  final String name;

  TtsLanguage({required this.code, required this.name});
}
