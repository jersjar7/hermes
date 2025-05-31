// lib/core/hermes_engine/state/hermes_session_state.dart

import 'hermes_status.dart';

/// Immutable state representing the entire Hermes session at a point in time.
class HermesSessionState {
  /// Current engine status
  final HermesStatus status;

  /// Countdown seconds remaining (when in countdown)
  final int? countdownSeconds;

  /// Last raw transcription received from STT
  final String? lastTranscript;

  /// Last translation received from TranslationService
  final String? lastTranslation;

  /// Buffered translated segments awaiting playback
  final List<String> buffer;

  /// Error message, if any
  final String? errorMessage;

  /// Total number of audience members
  final int audienceCount;

  /// Distribution of audience by language (language code -> count)
  final Map<String, int> languageDistribution;

  const HermesSessionState({
    required this.status,
    this.countdownSeconds,
    this.lastTranscript,
    this.lastTranslation,
    this.buffer = const [],
    this.errorMessage,
    this.audienceCount = 0,
    this.languageDistribution = const {},
  });

  /// Initial engine state before any session starts
  factory HermesSessionState.initial() {
    return const HermesSessionState(
      status: HermesStatus.idle,
      buffer: [],
      audienceCount: 0,
      languageDistribution: {},
    );
  }

  /// Returns a copy of this state with any provided overrides
  HermesSessionState copyWith({
    HermesStatus? status,
    int? countdownSeconds,
    String? lastTranscript,
    String? lastTranslation,
    List<String>? buffer,
    String? errorMessage,
    int? audienceCount,
    Map<String, int>? languageDistribution,
  }) {
    return HermesSessionState(
      status: status ?? this.status,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      lastTranslation: lastTranslation ?? this.lastTranslation,
      buffer: buffer ?? this.buffer,
      errorMessage: errorMessage,
      audienceCount: audienceCount ?? this.audienceCount,
      languageDistribution: languageDistribution ?? this.languageDistribution,
    );
  }

  /// Whether there are any audience members
  bool get hasAudience => audienceCount > 0;

  /// Total number of unique languages being listened to
  int get uniqueLanguageCount => languageDistribution.length;

  /// Most popular target language (or null if no audience)
  String? get mostPopularLanguage {
    if (languageDistribution.isEmpty) return null;

    return languageDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Gets a formatted string of audience distribution
  /// Example: "12 listeners: 8 Spanish, 4 French"
  String get audienceDistributionText {
    if (audienceCount == 0) return 'No listeners';

    final listenerText = audienceCount == 1 ? 'listener' : 'listeners';

    if (languageDistribution.isEmpty) {
      return '$audienceCount $listenerText';
    }

    final sortedLanguages =
        languageDistribution.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final languageList = sortedLanguages
        .map((entry) => '${entry.value} ${entry.key}')
        .join(', ');

    return '$audienceCount $listenerText: $languageList';
  }

  @override
  String toString() {
    return 'HermesSessionState(status: $status, '
        'countdownSeconds: $countdownSeconds, '
        'lastTranscript: $lastTranscript, '
        'lastTranslation: $lastTranslation, '
        'bufferSize: ${buffer.length}, '
        'audienceCount: $audienceCount, '
        'languageDistribution: $languageDistribution, '
        'error: $errorMessage)';
  }
}
