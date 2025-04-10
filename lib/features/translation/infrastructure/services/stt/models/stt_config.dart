// lib/features/translation/infrastructure/services/stt/models/stt_config.dart

/// Speech-to-Text configuration options
class SttConfig {
  /// Language code to recognize (e.g., 'en-US', 'es', 'fr')
  final String languageCode;

  /// Whether to enable automatic punctuation
  final bool enableAutomaticPunctuation;

  /// Whether to filter profanity
  final bool profanityFilter;

  /// Whether to enable interim results
  final bool interimResults;

  /// Whether to enable spoken punctuation (like "comma", "period")
  final bool enableSpokenPunctuation;

  /// Whether to enable emojis in text (like "heart emoji", "smile emoji")
  final bool enableSpokenEmojis;

  /// Whether to allow data logging for improving the model
  final bool enableDataLogging;

  /// Model to use (e.g., 'latest_short', 'phone_call', 'video')
  final String model;

  /// Sample rate of the audio in hertz
  final int sampleRateHertz;

  /// Creates a new [SttConfig]
  const SttConfig({
    required this.languageCode,
    this.enableAutomaticPunctuation = true,
    this.profanityFilter = false,
    this.interimResults = true,
    this.enableSpokenPunctuation = true,
    this.enableSpokenEmojis = true,
    this.enableDataLogging = true,
    this.model = 'latest_short',
    this.sampleRateHertz = 16000,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'config': {
        'autoDecodingConfig': {},
        'languageCodes': [languageCode],
        'model': model,
        'adaptation': {'phraseSets': [], 'customClasses': []},
        'recognition_features': {
          'enableAutomaticPunctuation': enableAutomaticPunctuation,
          'profanityFilter': profanityFilter,
          'enableSpokenPunctuation': enableSpokenPunctuation,
          'enableSpokenEmojis': enableSpokenEmojis,
        },
        'transcription_format': {
          'transcriptNormalization': {
            'enableLowerCaseOutput': false,
            'enableTranscriptNormalization': true,
          },
        },
        'streaming_features': {'interimResults': interimResults},
        'logging_options': {'enableDataLogging': enableDataLogging},
      },
      'recognitionOutputConfig': {
        'returnAlternatives': false,
        'maxAlternatives': 1,
      },
    };
  }

  /// Convert to JSON for batch requests
  Map<String, dynamic> toBatchJson() {
    final json = toJson();
    // Remove streaming-specific options for batch requests
    json['config'].remove('streaming_features');
    return json;
  }
}
