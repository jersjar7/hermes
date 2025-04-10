/// Speech-to-Text configuration options
class SttConfig {
  /// Language code to recognize (e.g., 'en-US', 'es', 'fr')
  final String languageCode;

  /// Whether to enable automatic punctuation
  final bool enableAutomaticPunctuation;

  /// Whether to filter profanity
  final bool profanityFilter;

  /// Whether to enable interim results (for streaming only)
  final bool interimResults;

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
    this.model = 'latest_short',
    this.sampleRateHertz = 16000,
  });

  /// Convert to JSON for batch recognition requests
  Map<String, dynamic> toJsonWithAudioContent(String base64Audio) {
    return {
      'config': {
        'encoding': 'LINEAR16',
        'sampleRateHertz': sampleRateHertz,
        'languageCode': languageCode,
        'enableAutomaticPunctuation': enableAutomaticPunctuation,
        'profanityFilter': profanityFilter,
        'audioChannelCount': 1,
        'model': model,
      },
      'audio': {'content': base64Audio},
    };
  }

  /// Convert to JSON for streaming recognition requests
  Map<String, dynamic> toStreamingConfig() {
    return {
      'config': {
        'encoding': 'LINEAR16',
        'sampleRateHertz': sampleRateHertz,
        'languageCode': languageCode,
        'enableAutomaticPunctuation': enableAutomaticPunctuation,
        'profanityFilter': profanityFilter,
        'audioChannelCount': 1,
        'model': model,
      },
      'interimResults': interimResults,
      'singleUtterance': false,
    };
  }
}
