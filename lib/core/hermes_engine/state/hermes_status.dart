// lib/core/hermes_engine/state/hermes_status.dart

/// Represents the high-level lifecycle states of the HermesEngine.
enum HermesStatus {
  /// Engine is idle; no active session or operations.
  idle,

  /// Engine is actively listening for speech input.
  listening,

  /// Engine is translating a received transcript.
  translating,

  /// Engine is buffering translated segments before speaking.
  buffering,

  /// Engine is in countdown mode before starting/resuming playback.
  countdown,

  /// Engine is actively speaking translated text via TTS.
  speaking,

  /// Engine is paused due to buffer depletion or connectivity loss.
  paused,

  /// An error has occurred; engine is in an error state.
  error,
}
