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

  const HermesSessionState({
    required this.status,
    this.countdownSeconds,
    this.lastTranscript,
    this.lastTranslation,
    this.buffer = const [],
    this.errorMessage,
  });

  /// Initial engine state before any session starts
  factory HermesSessionState.initial() {
    return const HermesSessionState(status: HermesStatus.idle, buffer: []);
  }

  /// Returns a copy of this state with any provided overrides
  HermesSessionState copyWith({
    HermesStatus? status,
    int? countdownSeconds,
    String? lastTranscript,
    String? lastTranslation,
    List<String>? buffer,
    String? errorMessage,
  }) {
    return HermesSessionState(
      status: status ?? this.status,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      lastTranslation: lastTranslation ?? this.lastTranslation,
      buffer: buffer ?? this.buffer,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'HermesSessionState(status: $status, '
        'countdownSeconds: $countdownSeconds, '
        'lastTranscript: $lastTranscript, '
        'lastTranslation: $lastTranslation, '
        'bufferSize: ${buffer.length}, '
        'error: $errorMessage)';
  }
}
