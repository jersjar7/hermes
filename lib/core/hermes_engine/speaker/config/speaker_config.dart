// lib/core/hermes_engine/speaker/config/speaker_config.dart
// Configuration constants and thresholds for SpeakerEngine

/// Configuration class containing all constants and thresholds for SpeakerEngine
class SpeakerConfig {
  SpeakerConfig._();

  // ==================== TIMING CONFIGURATION ====================

  /// Main processing interval for accumulating and processing text
  static const Duration processingInterval = Duration(seconds: 5);

  /// Interval for checking if buffer should be force flushed
  static const Duration forceFlushCheckInterval = Duration(seconds: 5);

  /// Maximum delay before processing incomplete sentences
  static const Duration maxProcessingDelay = Duration(seconds: 15);

  // ==================== DUPLICATE DETECTION ====================

  /// Similarity threshold for detecting duplicate text (0.0 to 1.0)
  /// Texts with similarity above this threshold are considered duplicates
  static const double similarityThreshold = 0.85;

  /// Minimum expansion ratio to consider text as valid expansion
  /// Text must be at least 10% longer to be processed as expansion
  static const double minimumExpansionRatio = 1.1;

  /// Maximum allowed length difference ratio for similar texts
  /// If length difference is below this ratio, texts are considered duplicates
  static const double maxLengthDifferenceRatio = 0.1;

  // ==================== MEMORY MANAGEMENT ====================

  /// Maximum number of processed texts to keep in memory
  /// Cache is cleared when this limit is exceeded to prevent memory bloat
  static const int maxProcessedTextsCache = 50;

  /// Number of characters to show in debug logs for text preview
  static const int debugTextPreviewLength = 50;

  /// Maximum number of characters to show in similarity comparison logs
  static const int debugSimilarityPreviewLength = 40;

  // ==================== BUFFER CONFIGURATION ====================

  /// Maximum number of sentences to accumulate before forcing processing
  static const int maxAccumulatedSentences = 5;

  /// Maximum buffer size in characters before forcing flush
  static const int maxBufferCharacters = 500;

  // ==================== TRANSLATION & PROCESSING ====================

  /// Timeout for grammar correction operations
  static const Duration grammarCorrectionTimeout = Duration(seconds: 10);

  /// Timeout for translation operations
  static const Duration translationTimeout = Duration(seconds: 15);

  /// Maximum number of retries for failed processing operations
  static const int maxProcessingRetries = 3;

  // ==================== AUDIENCE MANAGEMENT ====================

  /// Default audience count when no listeners are connected
  static const int defaultAudienceCount = 0;

  /// Maximum number of language distributions to track
  static const int maxLanguageDistributions = 20;

  // ==================== SOCKET & CONNECTIVITY ====================

  /// Delay after stopping STT before proceeding with cleanup
  static const Duration sttStopDelay = Duration(milliseconds: 100);

  /// Delay after state emission for proper state propagation
  static const Duration stateEmissionDelay = Duration(milliseconds: 50);

  /// Timeout for socket disconnect operations
  static const Duration socketDisconnectTimeout = Duration(seconds: 5);

  // ==================== ANALYTICS & LOGGING ====================

  /// Minimum processing time to log performance warnings
  static const Duration performanceWarningThreshold = Duration(seconds: 2);

  /// Maximum log message length for truncation
  static const int maxLogMessageLength = 200;

  // ==================== VALIDATION HELPERS ====================

  /// Validates if a similarity score is within valid range
  static bool isValidSimilarityScore(double similarity) {
    return similarity >= 0.0 && similarity <= 1.0;
  }

  /// Checks if text length qualifies for processing
  static bool isTextLengthValid(String text) {
    return text.trim().isNotEmpty && text.isNotEmpty;
  }

  /// Validates if expansion ratio meets minimum threshold
  static bool isValidExpansion(double ratio) {
    return ratio >= minimumExpansionRatio;
  }

  /// Checks if processing cache needs cleanup
  static bool shouldClearProcessedCache(int cacheSize) {
    return cacheSize > maxProcessedTextsCache;
  }

  /// Validates if language code is properly formatted
  static bool isValidLanguageCode(String languageCode) {
    return languageCode.isNotEmpty && languageCode.length >= 2;
  }
}

/// Enumeration of different processing trigger reasons
enum ProcessingTriggerReason {
  /// Processing triggered by timer interval
  timer,

  /// Processing triggered by complete sentence detection
  punctuation,

  /// Processing triggered by force flush conditions
  force,

  /// Processing triggered during session stop
  stop,

  /// Processing triggered manually
  manual,
}

/// Extension methods for ProcessingTriggerReason
extension ProcessingTriggerReasonExtension on ProcessingTriggerReason {
  /// Human-readable description of the trigger reason
  String get description {
    switch (this) {
      case ProcessingTriggerReason.timer:
        return 'Timer interval reached';
      case ProcessingTriggerReason.punctuation:
        return 'Complete sentence detected';
      case ProcessingTriggerReason.force:
        return 'Force flush triggered';
      case ProcessingTriggerReason.stop:
        return 'Session stopping';
      case ProcessingTriggerReason.manual:
        return 'Manual trigger';
    }
  }

  /// Whether this trigger reason indicates high priority processing
  bool get isHighPriority {
    return this == ProcessingTriggerReason.punctuation ||
        this == ProcessingTriggerReason.stop;
  }

  /// Whether this trigger reason should skip duplicate detection
  bool get shouldSkipDuplicateDetection {
    return this == ProcessingTriggerReason.stop;
  }
}
