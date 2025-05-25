// lib/core/services/text_to_speech/tts_settings.dart
/// Encapsulates text-to-speech configuration options.
class TtsSettings {
  final String languageCode;
  final double pitch;
  final double speechRate;

  const TtsSettings({
    required this.languageCode,
    required this.pitch,
    required this.speechRate,
  });

  factory TtsSettings.defaultSettings() {
    return const TtsSettings(
      languageCode: 'en-US',
      pitch: 1.0,
      speechRate: 1.0,
    );
  }
}
