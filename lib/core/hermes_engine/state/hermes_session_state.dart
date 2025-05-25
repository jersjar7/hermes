import 'hermes_status.dart';

/// Represents the complete state of a Hermes session.
class HermesSessionState {
  /// Current high-level status of the engine.
  final HermesStatus status;

  /// Current countdown seconds remaining, if in countdown mode.
  final int? countdownSeconds;

  /// The last received transcription from STT (raw input).
  final String? lastTranscript;

  /// The last translated sentence received.
  final String? lastTranslation;

  /// The list of pending translations in the buffer.
  final List<String> buffer;

  /// Error message if an error occurred.
  final String? errorMessage;

  const HermesSessionState({
    required this.status,
    this.countdownSeconds,
    this.lastTranscript,
    this.lastTranslation,
    this.buffer = const [],
    this.errorMessage,
  });

  /// Initial state of the engine when idle.
  factory HermesSessionState.initial() =>
      const HermesSessionState(status: HermesStatus.idle, buffer: []);

  /// Helper method to update session state reactively.
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
        'countdown: $countdownSeconds, '
        'lastTranscript: $lastTranscript, '
        'lastTranslation: $lastTranslation, '
        'bufferSize: ${buffer.length}, '
        'error: $errorMessage)';
  }
}
