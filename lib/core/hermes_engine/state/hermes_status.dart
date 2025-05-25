/// Represents the lifecycle status of the HermesEngine during a live session.
enum HermesStatus {
  /// The engine is not running or has been explicitly stopped.
  idle,

  /// Actively listening to speech input (STT is running).
  listening,

  /// Actively translating a chunk of transcribed speech.
  translating,

  /// The engine is speaking a translated segment.
  speaking,

  /// The engine is buffering translated text before starting playback.
  buffering,

  /// Countdown timer is running before TTS playback begins or resumes.
  countdown,

  /// The engine paused because the speaker stopped and buffer was exhausted.
  paused,

  /// An error occurred — UI should react accordingly.
  error,
}
