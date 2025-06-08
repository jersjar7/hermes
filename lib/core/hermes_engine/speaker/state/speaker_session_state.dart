// lib/core/hermes_engine/speaker/state/speaker_session_state.dart
// Extended state management structures for SpeakerEngine

import 'package:hermes/core/hermes_engine/state/hermes_session_state.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';

/// Processing type enumeration for text processing pipeline
enum ProcessingType {
  /// Completely new text content
  newContent,

  /// Expansion or replacement of existing text
  replacement,
}

/// Extension methods for ProcessingType
extension ProcessingTypeExtension on ProcessingType {
  /// Human-readable description of the processing type
  String get description {
    switch (this) {
      case ProcessingType.newContent:
        return 'New Content';
      case ProcessingType.replacement:
        return 'Text Replacement';
    }
  }

  /// Whether this processing type should trigger UI updates
  bool get shouldEmitToUI {
    switch (this) {
      case ProcessingType.newContent:
        return true;
      case ProcessingType.replacement:
        return false; // Prevent UI duplicates
    }
  }
}

/// Enhanced session state specifically for speaker engine operations
class SpeakerSessionState extends HermesSessionState {
  /// Current target language code for translations
  final String? targetLanguageCode;

  /// Whether the current content is a replacement of previous content
  final bool isReplacement;

  /// The original text that was replaced (if applicable)
  final String? replacedText;

  /// Current processing pipeline stage
  final ProcessingStage? currentProcessingStage;

  /// Performance metrics for the current session
  final SpeakerPerformanceMetrics? performanceMetrics;

  /// Buffer statistics
  final BufferStatistics? bufferStats;

  const SpeakerSessionState({
    required super.status,
    super.errorMessage,
    super.audienceCount,
    super.languageDistribution,
    super.lastTranscript,
    super.lastProcessedSentence,
    super.lastTranslation,
    this.targetLanguageCode,
    this.isReplacement = false,
    this.replacedText,
    this.currentProcessingStage,
    this.performanceMetrics,
    this.bufferStats,
  });

  /// Creates initial speaker session state
  factory SpeakerSessionState.initial() {
    return const SpeakerSessionState(status: HermesStatus.idle);
  }

  /// Creates a copy with updated properties
  @override
  SpeakerSessionState copyWith({
    HermesStatus? status,
    String? errorMessage,
    int? audienceCount,
    Map<String, int>? languageDistribution,
    String? lastTranscript,
    String? lastProcessedSentence,
    String? lastTranslation,
    List<String>? buffer, // From parent class
    int? countdownSeconds, // From parent class
    // Speaker-specific properties
    String? targetLanguageCode,
    bool? isReplacement,
    String? replacedText,
    ProcessingStage? currentProcessingStage,
    SpeakerPerformanceMetrics? performanceMetrics,
    BufferStatistics? bufferStats,
  }) {
    return SpeakerSessionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      audienceCount: audienceCount ?? this.audienceCount,
      languageDistribution: languageDistribution ?? this.languageDistribution,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      lastProcessedSentence:
          lastProcessedSentence ?? this.lastProcessedSentence,
      lastTranslation: lastTranslation ?? this.lastTranslation,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      isReplacement: isReplacement ?? this.isReplacement,
      replacedText: replacedText ?? this.replacedText,
      currentProcessingStage:
          currentProcessingStage ?? this.currentProcessingStage,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
      bufferStats: bufferStats ?? this.bufferStats,
    );
    // Note: buffer and countdownSeconds are inherited from parent but not used in SpeakerSessionState
  }

  /// Whether the session has an active audience
  @override
  bool get hasAudience => audienceCount > 0;

  /// Whether the session is actively processing
  bool get isProcessing => currentProcessingStage != null;

  /// Whether there's recent transcript content
  bool get hasRecentTranscript => lastTranscript?.isNotEmpty == true;

  /// Total number of supported languages in audience
  int get supportedLanguageCount => languageDistribution.keys.length;

  @override
  String toString() {
    return 'SpeakerSessionState{'
        'status: $status, '
        'audienceCount: $audienceCount, '
        'hasTranscript: $hasRecentTranscript, '
        'targetLanguage: $targetLanguageCode, '
        'isProcessing: $isProcessing'
        '}';
  }
}

/// Enumeration of processing pipeline stages
enum ProcessingStage {
  /// Receiving speech input
  speechRecognition,

  /// Applying grammar corrections
  grammarCorrection,

  /// Translating text
  translation,

  /// Broadcasting to audience
  broadcasting,

  /// Updating UI state
  stateUpdate,
}

/// Extension methods for ProcessingStage
extension ProcessingStageExtension on ProcessingStage {
  /// Human-readable description of the processing stage
  String get description {
    switch (this) {
      case ProcessingStage.speechRecognition:
        return 'Speech Recognition';
      case ProcessingStage.grammarCorrection:
        return 'Grammar Correction';
      case ProcessingStage.translation:
        return 'Translation';
      case ProcessingStage.broadcasting:
        return 'Broadcasting';
      case ProcessingStage.stateUpdate:
        return 'State Update';
    }
  }

  /// Emoji representation for logs
  String get emoji {
    switch (this) {
      case ProcessingStage.speechRecognition:
        return '🎤';
      case ProcessingStage.grammarCorrection:
        return '📝';
      case ProcessingStage.translation:
        return '🌍';
      case ProcessingStage.broadcasting:
        return '📡';
      case ProcessingStage.stateUpdate:
        return '🔄';
    }
  }
}

/// Performance metrics for speaker session
class SpeakerPerformanceMetrics {
  /// Total number of texts processed
  final int totalProcessedTexts;

  /// Total number of duplicates detected and skipped
  final int duplicatesSkipped;

  /// Total number of text replacements/expansions
  final int replacementsProcessed;

  /// Average grammar correction latency
  final Duration avgGrammarLatency;

  /// Average translation latency
  final Duration avgTranslationLatency;

  /// Total session duration
  final Duration sessionDuration;

  /// Number of processing errors
  final int processingErrors;

  const SpeakerPerformanceMetrics({
    this.totalProcessedTexts = 0,
    this.duplicatesSkipped = 0,
    this.replacementsProcessed = 0,
    this.avgGrammarLatency = Duration.zero,
    this.avgTranslationLatency = Duration.zero,
    this.sessionDuration = Duration.zero,
    this.processingErrors = 0,
  });

  /// Creates updated metrics with new values
  SpeakerPerformanceMetrics copyWith({
    int? totalProcessedTexts,
    int? duplicatesSkipped,
    int? replacementsProcessed,
    Duration? avgGrammarLatency,
    Duration? avgTranslationLatency,
    Duration? sessionDuration,
    int? processingErrors,
  }) {
    return SpeakerPerformanceMetrics(
      totalProcessedTexts: totalProcessedTexts ?? this.totalProcessedTexts,
      duplicatesSkipped: duplicatesSkipped ?? this.duplicatesSkipped,
      replacementsProcessed:
          replacementsProcessed ?? this.replacementsProcessed,
      avgGrammarLatency: avgGrammarLatency ?? this.avgGrammarLatency,
      avgTranslationLatency:
          avgTranslationLatency ?? this.avgTranslationLatency,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      processingErrors: processingErrors ?? this.processingErrors,
    );
  }

  /// Calculate overall processing efficiency (0.0 to 1.0)
  double get processingEfficiency {
    if (totalProcessedTexts == 0) return 1.0;
    final successfulProcessing = totalProcessedTexts - processingErrors;
    return successfulProcessing / totalProcessedTexts;
  }

  /// Calculate duplicate detection efficiency (0.0 to 1.0)
  double get duplicateDetectionRate {
    final totalTexts = totalProcessedTexts + duplicatesSkipped;
    if (totalTexts == 0) return 0.0;
    return duplicatesSkipped / totalTexts;
  }
}

/// Buffer statistics for monitoring buffer performance
class BufferStatistics {
  /// Current number of pending sentences in buffer
  final int pendingSentences;

  /// Current buffer size in characters
  final int bufferCharacters;

  /// Number of timer-based flushes
  final int timerFlushes;

  /// Number of force flushes due to buffer limits
  final int forceFlushes;

  /// Number of punctuation-based flushes
  final int punctuationFlushes;

  /// Total number of buffer operations
  final int totalBufferOperations;

  const BufferStatistics({
    this.pendingSentences = 0,
    this.bufferCharacters = 0,
    this.timerFlushes = 0,
    this.forceFlushes = 0,
    this.punctuationFlushes = 0,
    this.totalBufferOperations = 0,
  });

  /// Creates updated buffer statistics
  BufferStatistics copyWith({
    int? pendingSentences,
    int? bufferCharacters,
    int? timerFlushes,
    int? forceFlushes,
    int? punctuationFlushes,
    int? totalBufferOperations,
  }) {
    return BufferStatistics(
      pendingSentences: pendingSentences ?? this.pendingSentences,
      bufferCharacters: bufferCharacters ?? this.bufferCharacters,
      timerFlushes: timerFlushes ?? this.timerFlushes,
      forceFlushes: forceFlushes ?? this.forceFlushes,
      punctuationFlushes: punctuationFlushes ?? this.punctuationFlushes,
      totalBufferOperations:
          totalBufferOperations ?? this.totalBufferOperations,
    );
  }

  /// Whether buffer is approaching capacity limits
  bool get isNearCapacity => bufferCharacters > 400; // 80% of 500 char limit

  /// Whether buffer should be force flushed
  bool get shouldForceFlush => pendingSentences >= 5 || bufferCharacters >= 500;

  /// Buffer utilization ratio (0.0 to 1.0)
  double get bufferUtilization => bufferCharacters / 500.0;
}
